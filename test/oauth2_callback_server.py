#!/usr/bin/env python3
"""Minimal local OAuth2 callback server for AgentCore Identity.

Handles the session-binding step of the 3-legged OAuth2 flow:
  1. AgentCore redirects the user's browser here after Google consent
  2. This server calls CompleteResourceTokenAuth to bind the token
  3. Shows a success page so the user knows they can retry

Usage:
    python test/oauth2_callback_server.py --region eu-west-1 --user-id <USER_ID>

Then use the printed callback URL when updating your workload identity's
AllowedResourceOauth2ReturnUrls.
"""

import argparse
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, unquote

from config import add_aws_args, boto_session, OAUTH2_CALLBACK_PORT, OAUTH2_CALLBACK_PATH

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")

# Set by CLI args
_client = None
_user_id = None


class CallbackHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/ping":
            self._respond(200, "ok")
            return

        if parsed.path != OAUTH2_CALLBACK_PATH:
            self._respond(404, "Not found")
            return

        params = parse_qs(parsed.query)
        session_id = params.get("session_id", [None])[0]

        if not session_id:
            self._respond(400, "Missing session_id query parameter")
            return

        # parse_qs already decodes %3A → :, but let's be safe
        session_id = unquote(session_id)
        logger.info("Received callback with session_id=%s", session_id)

        try:
            _client.complete_resource_token_auth(
                sessionUri=session_id,
                userIdentifier={"userId": _user_id},
            )
            logger.info("CompleteResourceTokenAuth succeeded")
            html = (
                "<html><body style='font-family:sans-serif;text-align:center;padding:60px'>"
                "<h1 style='color:green'>&#10003; Authorization complete!</h1>"
                "<p>You can close this tab and retry your agent request.</p>"
                "</body></html>"
            )
            self._respond_html(200, html)
        except Exception as e:
            logger.exception("CompleteResourceTokenAuth failed")
            self._respond(500, f"Error: {e}")

    def _respond(self, code, msg):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(msg.encode())

    def _respond_html(self, code, html):
        self.send_response(code)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(html.encode())

    def log_message(self, fmt, *args):
        pass  # suppress default access logs


def main():
    global _client, _user_id

    parser = argparse.ArgumentParser(description="Local OAuth2 callback server")
    add_aws_args(parser)
    parser.add_argument("--port", type=int, default=OAUTH2_CALLBACK_PORT)
    parser.add_argument("--user-id", required=True, help="Same user ID passed to invoke.py --user-id")
    args = parser.parse_args()

    _user_id = args.user_id
    session = boto_session(args)
    _client = session.client("bedrock-agentcore")

    callback_url = f"http://localhost:{args.port}{OAUTH2_CALLBACK_PATH}"
    print(f"\nCallback URL: {callback_url}")
    print(f"User ID:      {_user_id}")
    print(f"Listening on port {args.port}...\n")
    print("Keep this running while you complete the OAuth2 flow.\n")

    server = HTTPServer(("127.0.0.1", args.port), CallbackHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
