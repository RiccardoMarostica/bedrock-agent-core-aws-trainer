# AWS Documentation MCP Server

An MCP (Model Context Protocol) server that exposes official AWS documentation search, reading, and recommendation tools. Built as a wrapper around the upstream [`awslabs.aws-documentation-mcp-server`](https://github.com/awslabs/mcp/tree/main/src/aws-documentation-mcp-server) package, adapted for deployment on Amazon Bedrock AgentCore Runtime.

## Why a Wrapper?

The upstream package's `FastMCP` instance uses lazy handler registration that doesn't play well with AgentCore's tool sync mechanism. This wrapper creates its own `FastMCP` instance and re-registers the tool functions directly, following the official AgentCore sample pattern. This gives a clean, predictable server where all tools are available immediately at startup.

## Architecture

```
AgentCore Runtime (MCP protocol)
  │
  ▼
server.py — FastMCP (streamable-http, port 8000)
  │
  ├─ search_documentation  ← re-registered from upstream
  ├─ read_documentation    ← re-registered from upstream
  └─ recommend             ← re-registered from upstream
        │
        ▼
  awslabs.aws_documentation_mcp_server (PyPI package)
        │
        ▼
  AWS Documentation API
```

## Tools

| Tool | Description |
|------|-------------|
| `search_documentation` | Search AWS documentation by keyword or phrase. Returns matching pages with titles, URLs, and context snippets. |
| `read_documentation` | Fetch and read the content of a specific AWS documentation page by URL. |
| `recommend` | Get related documentation recommendations for a given AWS documentation page URL. |

## Source Files

| File | Purpose |
|------|---------|
| `server.py` | FastMCP wrapper. Creates the MCP server instance, re-registers upstream tools, configures transport security, and starts the streamable-http server. |
| `Dockerfile` | Multi-stage ARM64 build. Stage 1 installs `uv` and the upstream package into a venv. Stage 2 copies the venv into a lean Amazon Linux runtime image. |
| `docker-healthcheck.sh` | Docker health check — verifies the `server.py` process is running via `pgrep`. |
| `uv-requirements.txt` | Pinned `uv` version with hash verification for reproducible builds. |
| `Makefile` | Build, push, and login targets for ECR. |

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FASTMCP_LOG_LEVEL` | `WARNING` | Loguru log level for the MCP server |
| `FASTMCP_HOST` | `0.0.0.0` | Host to bind the HTTP server |
| `FASTMCP_PORT` | `8000` | Port for the streamable-http transport |
| `AWS_DOCUMENTATION_PARTITION` | `aws` | AWS documentation partition (`aws`, `aws-cn`, `aws-us-gov`) |

### Transport Security

DNS rebinding protection is disabled at startup because AgentCore routes requests through an internal proxy with a non-localhost `Host` header. This is required for the server to accept requests from the AgentCore runtime.

## Container

### Multi-Stage Build

**Stage 1 (build):** Amazon Linux base
1. Installs Python 3 and `uv` (pinned version with hash verification from `uv-requirements.txt`)
2. Creates a Python 3.13 venv at `/app/.venv`
3. Installs `awslabs.aws-documentation-mcp-server` from PyPI into the venv

**Stage 2 (runtime):** Amazon Linux base
1. Copies the venv from stage 1
2. Copies `server.py` and `docker-healthcheck.sh`
3. Runs as non-root `app` user
4. Exposes port 8000
5. Health check every 60s via process detection

**Entrypoint:** `/app/.venv/bin/python /app/server.py`

### Health Check

```
Interval:     60s
Timeout:      10s
Start period: 10s
Retries:      3
Command:      pgrep -f "python /app/server.py"
```

## Build & Deploy

Run from `mcp/aws-documentation-mcp-server/`:

```bash
# Build ARM64 image locally
make build

# Authenticate to ECR and push
make push

# Build and push in one step
make build-push
```

### Makefile Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `eu-west-1` | Target AWS region |
| `AWS_PROFILE` | `default` | AWS CLI profile |
| `ECR_REPO` | *(must be set)* | ECR repository name |
| `IMAGE_TAG` | `latest` | Image tag |

The `push` target retrieves the ECR registry URL automatically via `aws ecr describe-repositories`, tags the local image, and pushes it.

## Integration with the Agent

The agent (`agent/aws-sap-trainer/`) can connect to this MCP server in two ways:

1. **Stdio (local/container):** The agent's `main.py` launches the upstream package directly via `uvx awslabs.aws-documentation-mcp-server@latest` as a stdio subprocess. This is the default mode and doesn't require this containerized server.

2. **AgentCore MCP Runtime:** This container is deployed as a separate AgentCore Runtime with `protocol = "MCP"`. The agent connects to it via the AgentCore Gateway, which routes MCP tool calls to the server's streamable-http endpoint. This mode enables centralized tool management and credential injection.
