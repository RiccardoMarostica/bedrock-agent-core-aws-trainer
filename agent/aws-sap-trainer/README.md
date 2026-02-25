# AWS SAP Trainer Agent

The AWS SAP Trainer is an AI-powered exam coaching agent that helps users prepare for the AWS Certified Solutions Architect — Professional certification. It runs on Amazon Bedrock AgentCore Runtime as an ARM64 container.

## Architecture

```
POST /invocations { "prompt": "...", "session_id": "..." }
  │
  ▼
main.py — invoke(payload)
  │
  ├─ memory.retrieve(query, session_id)
  │    ├─ Semantic namespace:       aws_knowledge
  │    ├─ Summarization namespace:  study_sessions_{sessionId}
  │    └─ User preference namespace: learner_profile
  │
  ├─ Augmented prompt = <memory>...</memory> + user message
  │
  ├─ _create_agent()
  │    ├─ BedrockModel (singleton) → Claude Haiku 4.5
  │    ├─ MCPClient (singleton)    → AWS Documentation MCP Server (via uvx)
  │    └─ Tools: save_session_to_google_drive, load_session_from_google_drive
  │
  ├─ agent(augmented_prompt) → response_text
  │
  ├─ memory.ingest(session_id, user_message, response_text)  ← fire-and-forget
  │
  └─ return {"result": response_text}
```

## Source Files

| File | Purpose |
|------|---------|
| `main.py` | Entry point. Configures `BedrockAgentCoreApp`, creates agents per invocation, handles the request/response lifecycle. |
| `memory.py` | AgentCore Memory helpers. Retrieves context from three strategy namespaces and ingests conversation turns. |
| `google_drive.py` | Google Drive session storage via AgentCore Identity OAuth2. Non-blocking token retrieval, Markdown file upload/download. |
| `requirements.txt` | Python dependencies |
| `Dockerfile` | ARM64 container build (python:3.11-slim-bookworm + uvx) |
| `Makefile` | Build, run, push, and test targets |

## Request / Response

**Endpoint:** `POST /invocations` (port 8080, managed by `BedrockAgentCoreApp`)

**Request payload:**

```json
{
  "prompt": "Explain the difference between S3 and EBS",
  "session_id": "session-2026-02-25"
}
```

- `prompt` — User message (defaults to `"Hello"` if omitted)
- `session_id` — Session identifier for memory scoping (defaults to `session-{today's date}`)

**Response:**

```json
{
  "result": "..."
}
```

**Health check:** `GET /ping` — Returns immediately, works even before the model is initialized.

## Concurrency Model

| Component | Lifecycle | Why |
|-----------|-----------|-----|
| `BedrockModel` | Lazy singleton | Stateless, safe to share across invocations |
| `MCPClient` | Lazy singleton | Holds the stdio connection to the MCP server process |
| `Agent` | Created per invocation | Carries conversation state, not safe to share |
| `IdentityClient` | Lazy singleton | Stateless HTTP client |

The container starts and responds to `/ping` immediately. The model and MCP client are initialized on the first `/invocations` call.

## Memory Integration

Memory is powered by AgentCore Memory via Boto3's `bedrock-agentcore` client. It is entirely optional — when `MEMORY_ID` is empty, all memory operations are no-ops.

### Retrieval

Queries three namespaces in parallel and assembles the results into an XML-tagged context block prepended to the user prompt:

```xml
<memory>
<semantic_memory>
- AWS fact 1
- AWS fact 2
</semantic_memory>
<session_memory>
- Previous session summary
</session_memory>
<user_preference_memory>
- User prefers hands-on examples
</user_preference_memory>
</memory>

{user's actual prompt}
```

Each namespace uses `retrieve_memory_records` with a configurable `TOP_K` (default 5). Errors are caught and logged — a failed retrieval never blocks the response.

### Ingestion

After the agent responds, the conversation turn (user message + assistant response) is ingested via `create_event`. This is fire-and-forget: errors are logged but never propagated.

The ingestion handles Strands' `Message` objects that may be returned as dicts instead of plain strings, extracting text content from the `{'role': 'assistant', 'content': [{'text': '...'}]}` structure.

### Memory Namespaces

| Strategy | Namespace | Configurable Via | Content |
|----------|-----------|------------------|---------|
| Semantic | `aws_knowledge` | `MEMORY_NAMESPACE` | AWS facts, patterns, exam gotchas |
| Summarization | `study_sessions_{sessionId}` | `MEMORY_NS_SUMMARIZATION` | Per-session conversation digests |
| User Preference | `learner_profile` | `MEMORY_NS_USER_PREFERENCE` | Learning style, knowledge gaps |

## Google Drive Integration

Session storage uses AgentCore Identity's OAuth2 flow to obtain Google access tokens, then the Google Drive API v3 to manage files.

### OAuth2 Flow

```
1. Agent calls _get_google_access_token()
2. IdentityClient.get_resource_oauth2_token() is called ONCE (no polling)
3a. If accessToken returned → proceed with Drive operations
3b. If authorizationUrl returned → return "AUTHORIZATION_REQUIRED: {url}" to user
4. User completes consent in browser → callback server calls CompleteResourceTokenAuth
5. Next tool invocation gets the cached token
```

The SDK's `@requires_access_token` decorator is intentionally avoided because it enters a blocking polling loop (up to 600 seconds) that would hang the AgentCore Runtime invocation handler.

The `sessionUri` is persisted across invocations so the retry after consent can resume the same OAuth2 session.

### Drive Operations

- Sessions are stored as Markdown files (`session_{session_id}.md`) in a configurable folder (default: `AgentCoreSessions`)
- `save_session_to_google_drive` — Creates or updates the session file with a summary and timestamp
- `load_session_from_google_drive` — Downloads and returns the Markdown content
- Folder is auto-created if it doesn't exist
- File updates use find-then-update semantics (not create duplicates)

### Strands Tools

Both functions are decorated with `@tool` from the Strands SDK, making them available to the agent as callable tools:

| Tool | Args | Description |
|------|------|-------------|
| `save_session_to_google_drive` | `session_id`, `summary` | Save session summary to Drive |
| `load_session_from_google_drive` | `session_id` | Load a previously saved session |

## MCP Integration

The agent connects to the AWS Documentation MCP Server via stdio using `uvx awslabs.aws-documentation-mcp-server@latest`. This provides three tools to the agent:

| MCP Tool | Purpose |
|----------|---------|
| `search_documentation` | Search AWS docs by keyword |
| `read_documentation` | Read a specific documentation page |
| `recommend` | Get related documentation recommendations |

The MCP client is a lazy singleton. The `uvx` binary is installed in the container image (copied from `ghcr.io/astral-sh/uv:latest`).

## System Prompt

The default system prompt defines the agent's persona as an expert AWS Technical Trainer. Key behaviors:

- Always searches official AWS documentation before answering (via MCP tools)
- Structures responses with: Executive Summary → Deep Dive → Use Cases → Code Examples → Exam Considerations
- Compares and contrasts related services
- Challenges the user with knowledge-check questions
- Handles `AUTHORIZATION_REQUIRED` responses from Google Drive tools by relaying the auth URL

The system prompt is fully overridable via the `SYSTEM_PROMPT` environment variable.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_ID` | `anthropic.claude-haiku-4-5-20251001-v1:0` | Bedrock model identifier |
| `AWS_REGION` | `eu-west-1` | AWS region for all service calls |
| `SYSTEM_PROMPT` | *(built-in SAP trainer prompt)* | Agent system prompt |
| `MEMORY_ID` | `""` (disabled) | AgentCore Memory ID |
| `MEMORY_ACTOR_ID` | `learner` | Actor ID for memory events |
| `MEMORY_NAMESPACE` | `aws_knowledge` | Semantic strategy namespace |
| `MEMORY_NS_SUMMARIZATION` | `study_sessions_{sessionId}` | Summarization namespace template |
| `MEMORY_NS_USER_PREFERENCE` | `learner_profile` | User preference namespace |
| `MEMORY_TOP_K` | `5` | Number of memory records to retrieve per namespace |
| `GOOGLE_OAUTH2_PROVIDER_NAME` | `google-drive-provider` | AgentCore Identity credential provider name |
| `GOOGLE_DRIVE_FOLDER_NAME` | `AgentCoreSessions` | Google Drive folder for session files |
| `OAUTH2_RETURN_URL` | `""` | OAuth2 callback URL for consent redirect |
| `LOG_LEVEL` | *(not set)* | Python logging level |

## Container

**Base image:** `python:3.11-slim-bookworm` (ARM64)

**Build layers:**
1. Install `uv`/`uvx` from `ghcr.io/astral-sh/uv:latest`
2. Install Python dependencies from `requirements.txt`
3. Copy application files (`main.py`, `memory.py`, `google_drive.py`)

**Exposed port:** 8080

**Dependencies:**

| Package | Purpose |
|---------|---------|
| `strands-agents` | Strands agentic framework |
| `strands-agents-tools` | Strands tool utilities |
| `bedrock-agentcore` | AgentCore Runtime, Identity, Memory SDKs |
| `mcp` | MCP protocol client |
| `mcp-proxy-for-aws` | MCP proxy for AWS services |
| `google-api-python-client` | Google Drive API v3 |
| `google-auth-httplib2` | Google auth HTTP transport |
| `google-auth-oauthlib` | Google OAuth2 credentials |

## Build & Deploy

Run from `agent/aws-sap-trainer/`:

```bash
# Build ARM64 image locally
make build

# Run locally with AWS credentials
make run

# Build and push to ECR with a version tag
make push TAG=v1.0.0

# Smoke test local container
make test-local
```

**Makefile variables** (override via env or CLI):

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `eu-west-1` | Target AWS region |
| `AWS_PROFILE` | `default` | AWS CLI profile |
| `ECR_REPO` | *(must be set)* | ECR repository name |
| `TAG` | `latest` | Image tag |

The `push` target automatically authenticates to ECR via `aws ecr get-login-password`, then builds and pushes in a single `docker buildx` command.
