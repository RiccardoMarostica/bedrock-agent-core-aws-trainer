# Test & Utility Scripts

CLI scripts for invoking and managing the AgentCore resources deployed by this project.

## Prerequisites

```bash
pip install boto3 httpx mcp botocore
```

An AWS CLI profile configured with permissions to call Bedrock AgentCore APIs. All scripts default to `--region eu-west-1` and `--profile default` (override with flags).

## Scripts

### `invoke.py` — Invoke the Agent Runtime

Sends a prompt to the AWS SAP Exam Coach agent running on AgentCore Runtime and prints the response. Supports streaming (`text/event-stream`) and JSON responses.

```bash
# Basic invocation
python test/invoke.py \
  --runtime-arn <RUNTIME_ARN> \
  --prompt "Explain the difference between S3 and EBS"

# With a specific session and user ID (required for OAuth2/Google Drive flows)
python test/invoke.py \
  --runtime-arn <RUNTIME_ARN> \
  --prompt "Save my session" \
  --session-id my-session-01 \
  --user-id <USER_ID>

# Custom endpoint name
python test/invoke.py \
  --runtime-arn <RUNTIME_ARN> \
  --endpoint-name my-endpoint \
  --prompt "Hello"
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--runtime-arn` | Yes | — | AgentCore Runtime ARN |
| `--prompt` | Yes | — | Prompt text to send |
| `--endpoint-name` | No | `DEFAULT` | Runtime endpoint qualifier |
| `--session-id` | No | random UUID | Conversation session ID |
| `--user-id` | No | `None` | Runtime user ID for identity flows |
| `--region` | No | `eu-west-1` | AWS region |
| `--profile` | No | `default` | AWS CLI profile |

### `invoke_mcp_runtime.py` — Invoke the MCP Server Runtime

Connects to an AgentCore MCP Runtime over streamable-http with SigV4 authentication. Lists available tools and optionally calls one.

```bash
# List available tools
python test/invoke_mcp_runtime.py \
  --runtime-arn <MCP_RUNTIME_ARN>

# Call a specific tool
python test/invoke_mcp_runtime.py \
  --runtime-arn <MCP_RUNTIME_ARN> \
  --tool search_documentation \
  --args '{"search_phrase": "Amazon S3 bucket versioning"}'
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--runtime-arn` | Yes | — | MCP Runtime ARN |
| `--tool` | No | `None` | Tool name to call (omit to just list tools) |
| `--args` | No | `{}` | Tool arguments as a JSON string |
| `--region` | No | `eu-west-1` | AWS region |
| `--profile` | No | `default` | AWS CLI profile |

### `oauth2_callback_server.py` — Local OAuth2 Callback Server

Runs a local HTTP server that handles the session-binding step of the 3-legged OAuth2 flow with AgentCore Identity. After the user completes Google consent, the browser redirects here and the server calls `CompleteResourceTokenAuth` to bind the token.

```bash
python test/oauth2_callback_server.py --user-id <USER_ID>
```

The server prints the callback URL on startup (default: `http://localhost:9090/oauth2/callback`). Register this URL in your workload identity's `AllowedResourceOauth2ReturnUrls` using `update_workload_identity.py` or Terraform.

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--user-id` | Yes | — | Same user ID passed to `invoke.py --user-id` |
| `--port` | No | `9090` | Local server port |
| `--region` | No | `eu-west-1` | AWS region |
| `--profile` | No | `default` | AWS CLI profile |

### `update_workload_identity.py` — Manage Workload Identities

Lists workload identities or adds an OAuth2 return URL to a specific one.

```bash
# List all workload identities
python test/update_workload_identity.py

# Add the callback URL to a workload identity
python test/update_workload_identity.py \
  --name <WORKLOAD_IDENTITY_NAME> \
  --add-url "http://localhost:9090/oauth2/callback"
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name` | No | — | Workload identity name (omit to list all) |
| `--add-url` | No | — | OAuth2 return URL to register |
| `--region` | No | `eu-west-1` | AWS region |
| `--profile` | No | `default` | AWS CLI profile |

## Shared Configuration

All scripts import from `config.py`, which centralises:

- Default AWS region and profile
- `boto_session()` helper for consistent session creation
- OAuth2 callback constants (port, path)

To change defaults project-wide, edit `test/config.py`.

## Typical Workflow

1. Deploy infrastructure with Terraform (`infrastructure/environments/dev/`)
2. Build and push the agent container (`agent/aws-sap-trainer/`)
3. Invoke the agent: `python test/invoke.py --runtime-arn <RUNTIME_ARN> --prompt "..."`
4. For Google Drive integration:
   - Start the callback server: `python test/oauth2_callback_server.py --user-id <USER_ID>`
   - Register the callback URL: `python test/update_workload_identity.py --name <NAME> --add-url "http://localhost:9090/oauth2/callback"`
   - Invoke with user ID: `python test/invoke.py --runtime-arn <RUNTIME_ARN> --user-id <USER_ID> --prompt "Save my session"`
5. For MCP server testing: `python test/invoke_mcp_runtime.py --runtime-arn <MCP_RUNTIME_ARN>`
