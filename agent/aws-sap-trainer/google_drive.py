"""Google Drive session storage via AgentCore Identity OAuth2.

Uses the IdentityClient from bedrock_agentcore directly instead of the
@requires_access_token decorator, which enters a blocking polling loop
(up to 600s) that hangs the AgentCore Runtime invocation handler.

We call GetResourceOauth2Token once:
  - If accessToken is returned → proceed with Google Drive operations.
  - If authorizationUrl is returned → return it to the agent immediately
    so it can relay it to the user for consent in their browser.
  - After the user completes consent, the next tool call gets the cached token.
"""

from __future__ import annotations

import io
import logging
import os
from datetime import datetime, timezone
from urllib.parse import unquote

from bedrock_agentcore.runtime import BedrockAgentCoreContext
from bedrock_agentcore.services.identity import IdentityClient
from strands import tool

logger = logging.getLogger(__name__)

GOOGLE_PROVIDER_NAME = os.getenv("GOOGLE_OAUTH2_PROVIDER_NAME", "google-drive-provider")
GOOGLE_DRIVE_FOLDER_NAME = os.getenv("GOOGLE_DRIVE_FOLDER_NAME", "AgentCoreSessions")
OAUTH2_RETURN_URL = os.getenv("OAUTH2_RETURN_URL", "")
AWS_REGION = os.getenv("AWS_REGION", os.getenv("AWS_DEFAULT_REGION", "eu-west-1"))

SCOPES = ["https://www.googleapis.com/auth/drive.file"]

# Persist session URI across invocations so we can resume after consent
_session_uri: str | None = None


# ---------------------------------------------------------------------------
# Token retrieval — single call, no polling
# ---------------------------------------------------------------------------

_identity_client: IdentityClient | None = None


def _get_identity_client() -> IdentityClient:
    global _identity_client
    if _identity_client is None:
        _identity_client = IdentityClient(AWS_REGION)
    return _identity_client


def _get_google_access_token() -> dict:
    """Single non-blocking call to get a Google OAuth2 token or auth URL.

    Returns dict with one of:
      {"access_token": str}          — ready to use
      {"authorization_url": str}     — user must complete consent
      {"error": str}                 — something went wrong
    """
    global _session_uri
    client = _get_identity_client()

    # The runtime injects the workload access token automatically
    workload_token = BedrockAgentCoreContext.get_workload_access_token()
    if workload_token is None:
        return {"error": (
            "Workload access token not available. "
            "If using SigV4 auth, include the X-Amzn-Bedrock-AgentCore-Runtime-User-Id header."
        )}

    # Build the request — same params the decorator would use
    req = {
        "resourceCredentialProviderName": GOOGLE_PROVIDER_NAME,
        "scopes": SCOPES,
        "oauth2Flow": "USER_FEDERATION",
        "workloadIdentityToken": workload_token,
        "forceAuthentication": False,
        "customParameters": {"access_type": "offline"},
    }
    # Pass the return URL so AgentCore redirects the user's browser to our
    # local callback server after Google consent.  The callback server calls
    # CompleteResourceTokenAuth to bind the token to the user.
    if OAUTH2_RETURN_URL:
        req["resourceOauth2ReturnUrl"] = OAUTH2_RETURN_URL
    if _session_uri:
        req["sessionUri"] = _session_uri

    response = client.dp_client.get_resource_oauth2_token(**req)

    # Persist session URI for the retry after consent
    if response.get("sessionUri"):
        _session_uri = response["sessionUri"]

    if response.get("accessToken"):
        return {"access_token": response["accessToken"]}
    if response.get("authorizationUrl"):
        # The API returns a URL-encoded authorization URL. Decode it so the
        # request_uri query-param value uses raw colons (urn:ietf:params:...)
        # instead of percent-encoded ones (%3A) — AgentCore's /authorize
        # endpoint rejects percent-encoded request_uri values.
        return {"authorization_url": unquote(response["authorizationUrl"])}
    if response.get("sessionStatus") == "FAILED":
        return {"error": "OAuth2 session failed. Please try again."}

    return {"error": f"Unexpected response: {response}"}


# ---------------------------------------------------------------------------
# Google Drive API helpers
# ---------------------------------------------------------------------------

def _build_drive_service(access_token: str):
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build

    creds = Credentials(token=access_token, scopes=SCOPES)
    return build("drive", "v3", credentials=creds)


def _find_or_create_folder(service, folder_name: str) -> str:
    query = (
        f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder' "
        f"and trashed=false"
    )
    results = service.files().list(q=query, fields="files(id, name)", pageSize=1).execute()
    files = results.get("files", [])
    if files:
        return files[0]["id"]

    metadata = {"name": folder_name, "mimeType": "application/vnd.google-apps.folder"}
    folder = service.files().create(body=metadata, fields="id").execute()
    return folder["id"]


def _session_to_markdown(session_data: dict) -> str:
    """Convert session data to a Markdown string."""
    lines = [
        f"# Session {session_data.get('session_id', 'unknown')}",
        "",
        f"**Saved at:** {session_data.get('saved_at', 'N/A')}",
        "",
        "## Summary",
        "",
        session_data.get("summary", ""),
        "",
    ]
    return "\n".join(lines)


def _upload_markdown(service, folder_id: str, filename: str, content: str) -> str:
    from googleapiclient.http import MediaIoBaseUpload

    query = f"name='{filename}' and '{folder_id}' in parents and trashed=false"
    existing = service.files().list(q=query, fields="files(id)", pageSize=1).execute()
    media = MediaIoBaseUpload(io.BytesIO(content.encode("utf-8")), mimetype="text/markdown")

    if existing.get("files"):
        file_id = existing["files"][0]["id"]
        service.files().update(fileId=file_id, media_body=media).execute()
        return file_id

    metadata = {"name": filename, "parents": [folder_id]}
    created = service.files().create(body=metadata, media_body=media, fields="id").execute()
    return created["id"]


def _download_markdown(service, folder_id: str, filename: str) -> str | None:
    query = f"name='{filename}' and '{folder_id}' in parents and trashed=false"
    results = service.files().list(q=query, fields="files(id)", pageSize=1).execute()
    files = results.get("files", [])
    if not files:
        return None

    content = service.files().get_media(fileId=files[0]["id"]).execute()
    return content.decode("utf-8") if isinstance(content, bytes) else content


# ---------------------------------------------------------------------------
# Strands @tool functions
# ---------------------------------------------------------------------------

@tool
def save_session_to_google_drive(session_id: str, summary: str) -> str:
    """Save the current study session to Google Drive.

    Stores a JSON file with the session summary in a dedicated Google Drive folder.
    If the user has not yet completed the Google OAuth2 consent flow, this tool
    returns the authorization URL that the user must open in their browser.

    Args:
        session_id: Unique identifier for the session.
        summary: A text summary of the session content to save.
    """
    try:
        token_result = _get_google_access_token()

        if "authorization_url" in token_result:
            return (
                f"AUTHORIZATION_REQUIRED: To save to Google Drive, please open this URL "
                f"in your browser and complete the Google consent flow, then ask me to "
                f"save again:\n\n{token_result['authorization_url']}"
            )
        if "error" in token_result:
            return f"Error getting Google token: {token_result['error']}"

        access_token = token_result["access_token"]
        session_data = {
            "session_id": session_id,
            "summary": summary,
            "saved_at": datetime.now(timezone.utc).isoformat(),
        }
        markdown_content = _session_to_markdown(session_data)
        service = _build_drive_service(access_token)
        folder_id = _find_or_create_folder(service, GOOGLE_DRIVE_FOLDER_NAME)
        filename = f"session_{session_id}.md"
        file_id = _upload_markdown(service, folder_id, filename, markdown_content)
        return f"Session saved to Google Drive: {filename} (file ID: {file_id})"

    except Exception as e:
        logger.exception("Failed to save session to Google Drive")
        return f"Error saving session to Google Drive: {e}"


@tool
def load_session_from_google_drive(session_id: str) -> str:
    """Load a previously saved study session from Google Drive.

    Retrieves the session JSON file from the dedicated Google Drive folder.
    If the user has not yet completed the Google OAuth2 consent flow, this tool
    returns the authorization URL that the user must open in their browser.

    Args:
        session_id: Unique identifier for the session to load.
    """
    try:
        token_result = _get_google_access_token()

        if "authorization_url" in token_result:
            return (
                f"AUTHORIZATION_REQUIRED: To load from Google Drive, please open this URL "
                f"in your browser and complete the Google consent flow, then ask me to "
                f"load again:\n\n{token_result['authorization_url']}"
            )
        if "error" in token_result:
            return f"Error getting Google token: {token_result['error']}"

        access_token = token_result["access_token"]
        service = _build_drive_service(access_token)
        folder_id = _find_or_create_folder(service, GOOGLE_DRIVE_FOLDER_NAME)
        filename = f"session_{session_id}.md"
        data = _download_markdown(service, folder_id, filename)
        if data is None:
            return f"No session found on Google Drive for session_id: {session_id}"
        return data

    except Exception as e:
        logger.exception("Failed to load session from Google Drive")
        return f"Error loading session from Google Drive: {e}"
