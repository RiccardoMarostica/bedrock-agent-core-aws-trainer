# Amazon Bedrock AgentCore Learning

A hands-on learning repository for building AI agents on AWS using Amazon Bedrock AgentCore. Includes a fully functional exam coaching agent, reusable Terraform modules, and integration examples for memory, identity/OAuth2, and MCP servers.

## Architecture

```
Client → AgentCore Runtime (HTTP :8080)
           → Strands Agent (Claude model)
              → Tools: Google Drive sessions, AWS Documentation (MCP)
           → AgentCore Memory (semantic retrieval + ingestion)
           ← JSON response
```

## Prerequisites

- **AWS Account** with Bedrock AgentCore access
- **AWS CLI** v2 configured with a named profile
- **Python** 3.11+
- **Docker** with buildx (for ARM64 images)
- **Terraform** >= 1.5
- **Node.js** (for changelog generation via `conventional-changelog`)

## Quick Start

### 1. Set up infrastructure

```bash
cd infrastructure/environments/dev
cp .env_template .env          # fill in your AWS profile
cp terraform.tfvars_template terraform.tfvars  # fill in your values
terraform init
terraform plan
terraform apply                # creates ECR, S3, IAM (with create_runtime=false)
```

### 2. Build and push the agent container

```bash
cd agent/aws-sap-trainer
make push TAG=v1.0.0
```

### 3. Deploy the agent runtime

Set `create_runtime = true` in `terraform.tfvars`, then:

```bash
cd infrastructure/environments/dev
terraform apply
```

### 4. Invoke the agent

```bash
python test/invoke.py \
  --runtime-arn <RUNTIME_ARN> \
  --prompt "Explain the difference between S3 and EBS"
```

## Project Structure

| Directory | Description |
|-----------|-------------|
| `agent/aws-sap-trainer/` | Python agent application (Strands + BedrockAgentCoreApp) |
| `infrastructure/modules/` | Reusable Terraform modules (runtime, memory, identity, gateway, ECR, S3, IAM) |
| `infrastructure/environments/` | Environment-specific Terraform configurations |
| `iam/` | IAM policy and trust policy JSON templates |
| `mcp/` | MCP server for AWS documentation access |
| `test/` | Invocation and utility scripts |
| `docs/` | Documentation and design plans |

## Releases

This project uses [Semantic Versioning](https://semver.org/). See [CONTRIBUTING.md](CONTRIBUTING.md) for release procedures.

## License

This project is licensed under the Apache License 2.0 — see [LICENSE](LICENSE) for details.
