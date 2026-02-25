# Amazon Bedrock AgentCore Learning — Project Overview

A hands-on learning repository for building AI agents on AWS using Amazon Bedrock AgentCore. Includes a fully functional exam coaching agent, reusable Terraform modules, and integration examples for memory, identity/OAuth2, MCP servers, and agent-to-agent gateways.

## Architecture

```
Client → AgentCore Runtime Endpoint (HTTP :8080)
           → main.py (BedrockAgentCoreApp)
              → memory.py (retrieve context from AgentCore Memory)
              → Strands Agent (Claude Haiku 4.5)
                 → Tools: Google Drive sessions, MCP AWS docs
              → memory.py (ingest conversation, fire-and-forget)
           ← {"result": "response_text"}
```

The agent runs as an ARM64 container inside Bedrock AgentCore Runtime. Each HTTP request creates a fresh Strands Agent instance (the underlying model and MCP client are lazy singletons shared across invocations). Memory retrieval augments the user prompt before inference, and memory ingestion happens asynchronously after the response is sent.

## Features & Capabilities

### 1. Conversational Exam Coaching Agent

The primary application (`agent/aws-sap-trainer/`) is an AWS Solutions Architect Professional exam coach built with the Strands agentic framework.

- Uses Claude Haiku 4.5 (`anthropic.claude-haiku-4-5-20251001-v1:0`) via Amazon Bedrock
- Structured responses: executive summary, deep dive, use cases, code examples, exam considerations
- Compares and contrasts related AWS services, challenges the user with knowledge checks
- Configurable system prompt via `SYSTEM_PROMPT` environment variable

### 2. AgentCore Memory (RAG)

Three-strategy memory system for retrieval-augmented generation, powered by AgentCore Memory:

| Strategy | Namespace | Purpose |
|----------|-----------|---------|
| Semantic | `aws_knowledge` | AWS facts, architectural patterns, exam gotchas |
| Summarization | `study_sessions_{sessionId}` | Per-session conversation digests |
| User Preference | `learner_profile` | Learning style, knowledge gaps, preferences |

Memory is optional — disabled when `MEMORY_ID` is not set. Retrieval queries all three namespaces and wraps results in XML tags (`<semantic_memory>`, `<session_memory>`, `<user_preference_memory>`). Ingestion is fire-and-forget and never blocks the response path.

### 3. Google Drive Session Storage

Save and load study sessions to Google Drive via AgentCore Identity OAuth2:

- Non-blocking OAuth2 flow: returns authorization URL immediately if no token is cached
- Sessions stored as Markdown files in a configurable Drive folder (`AgentCoreSessions` by default)
- Uses `IdentityClient` directly (avoids the blocking polling loop of `@requires_access_token`)
- Supports create-or-update semantics for session files

### 4. AWS Documentation MCP Server

A Model Context Protocol server (`mcp/aws-documentation-mcp-server/`) that gives the agent access to official AWS documentation:

- Wraps the upstream `awslabs.aws-documentation-mcp-server` package
- Re-registers tools (`read_documentation`, `search_documentation`, `recommend`) on a custom FastMCP instance for clean AgentCore integration
- Runs as streamable HTTP on port 8000, deployed as an ARM64 container
- DNS rebinding protection disabled for AgentCore's internal proxy

### 5. AgentCore Gateway (Agent Chaining)

Terraform module for creating an MCP-protocol gateway that routes requests to multiple agent targets:

- Lambda-based targets with inline tool definitions
- External MCP server targets with automatic tool discovery
- Credential provider support: OAuth2, API keys, or gateway IAM role
- Optional Lambda interceptors for request/response transformation
- JWT or IAM authorization for inbound requests

### 6. Cognito M2M Authentication

Machine-to-machine OAuth2 via Cognito User Pools for service-to-service auth:

- `client_credentials` grant flow
- Resource server with configurable scopes
- Used for Gateway → MCP Runtime outbound authentication

### 7. Workload Identity & Credential Management

AgentCore Identity module for managing inbound and outbound authentication:

- Workload identity with allowed OAuth2 return URLs
- Outbound OAuth2 credential providers (Google, GitHub, Microsoft, Slack, Custom)
- Outbound API key credential providers (stored in Token Vault backed by Secrets Manager)
- Optional customer-managed KMS encryption for the Token Vault

## Infrastructure

Eight reusable Terraform modules covering the full AgentCore stack:

| Module | What it creates |
|--------|----------------|
| `bedrock_agentcore_runtime` | Agent Runtime + Endpoint (container or code, VPC/public, HTTP/MCP/A2A) |
| `bedrock_agentcore_memory` | Memory store + strategies (semantic, summarization, user preference) |
| `bedrock_agentcore_identity` | Workload identity, OAuth2 providers, API key providers, Token Vault CMK |
| `bedrock_agentcore_gateway` | MCP gateway with Lambda/MCP server targets and interceptors |
| `cognito_m2m` | Cognito User Pool, resource server, M2M app client |
| `ecr` | ECR repository with scanning and lifecycle policies |
| `s3` | S3 bucket with versioning, public access blocking, optional CloudFront CDN |
| `iam` | IAM role with managed and custom policy attachments |

Deployment is phased via gate variables (`create_runtime`, `create_memory`, `create_identity`) to handle resource dependencies (e.g., ECR image must exist before the runtime can reference it).

Seven least-privilege IAM policy templates in `iam/policies/` cover ECR pull, S3 read, CloudWatch Logs, X-Ray, Bedrock model invocation, workload identity, memory data plane, and gateway invocation.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Agent framework | Strands Agents SDK |
| LLM | Claude Haiku 4.5 via Amazon Bedrock |
| Runtime | Bedrock AgentCore Runtime (ARM64 container, port 8080) |
| Memory | Bedrock AgentCore Memory |
| Identity/OAuth2 | Bedrock AgentCore Identity |
| Tool protocol | Model Context Protocol (MCP) via FastMCP |
| Infrastructure | Terraform >= 1.5, AWS provider >= 5.82.0 |
| Container | Docker with buildx (ARM64), python:3.11-slim-bookworm |
| CI/Build | Make, npm (`conventional-changelog` for releases) |
| Language | Python 3.11+ |

## Test & Invocation Scripts

| Script | Purpose |
|--------|---------|
| `test/invoke.py` | Invoke the agent runtime with a prompt via `--runtime-arn` |
| `test/invoke_mcp_runtime.py` | Test MCP runtime endpoints |
| `test/oauth2_callback_server.py` | Local HTTP server for OAuth2 callback handling |
| `test/update_workload_identity.py` | Update workload identity configuration |
| `test/config.py` | Shared test configuration |

## Key Design Decisions

- **Per-invocation agents**: A fresh `Agent` is created for each request to avoid concurrency issues. The `BedrockModel` and `MCPClient` are lazy singletons (stateless, safe to share).
- **Optional integrations**: Memory and Google Drive are gracefully disabled when their configuration is absent. Neither blocks the response path.
- **Non-blocking OAuth2**: Uses a single `GetResourceOauth2Token` call instead of the SDK's blocking polling decorator. Returns the auth URL immediately for user consent.
- **Two-phase infrastructure**: First apply creates foundational resources (ECR, S3, IAM). After pushing the container image, a second apply with `create_runtime = true` creates the runtime.
- **Least-privilege IAM**: Each policy template scopes actions to specific resources using `${region}` and `${account_id}` template variables.

## Documentation

Additional design and implementation documents are in `docs/plans/`:

| Document | Topic |
|----------|-------|
| Memory module design | AgentCore Memory architecture and strategy selection |
| Memory strategy implementation | Semantic, summarization, and user preference strategy details |
| Identity module design | Workload identity and credential provider architecture |
| Identity implementation | OAuth2 flows, API key storage, Token Vault |
| Public release generalization | Design for making the project reusable beyond the SAP trainer |
