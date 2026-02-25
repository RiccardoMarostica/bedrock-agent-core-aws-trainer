# Infrastructure (AWS)

This directory contains the Terraform code for the project's AWS infrastructure. The `infrastructure` folder organizes reusable modules and deployable environments.

## Directory Structure

- `modules/` — Reusable Terraform modules (one per service). Each module contains `main.tf`, `variables.tf`, `outputs.tf` and helper files.
- `environments/` — Deployable environments (e.g., `dev/`). Each environment has its own configuration (`main.tf`, `provider.tf`, `terraform.tfvars`, `.env`).

## Terraform Requirements

| Requirement | Version |
|-------------|---------|
| Terraform | >= 1.5 |
| AWS Provider | >= 5.82.0 |
| Time Provider | >= 0.9 |

State is stored in S3 with DynamoDB locking (configured per environment in `provider.tf`).

## Phased Deployment

Infrastructure uses a two-phase apply controlled by gate variables:

1. **Phase 1** — `create_runtime = false` (default): Creates ECR, S3, IAM roles and policies. Push the agent container image to ECR after this phase.
2. **Phase 2** — `create_runtime = true`: Creates the AgentCore Runtime and Endpoint using the pushed container image.

Additional gate variables: `create_memory` (default `false`), `create_identity` (default `false`).

## Environments

Environments live under `environments/`. Currently available:

- `dev/` — Development environment

Each environment contains:

| File | Purpose |
|------|---------|
| `main.tf` | Module instantiation and composition |
| `provider.tf` | AWS provider, backend configuration |
| `variables.tf` | Input variable definitions |
| `locals.tf` | Computed values (`account_id`, `region`, `use_container`, `common_tags`) |
| `outputs.tf` | Exported resource identifiers and ARNs |
| `terraform.tfvars` | Environment-specific variable values |
| `.env` | Environment variables (not committed) |

Default tags applied via provider `default_tags`: `Project`, `Environment`, `ManagedBy=terraform`.

---

## Modules

### `bedrock_agentcore_runtime`

Creates an AgentCore Agent Runtime and optionally a Runtime Endpoint for invoking the agent.

**Resources:**
- `aws_bedrockagentcore_agent_runtime` — The agent runtime (container or code-based)
- `aws_bedrockagentcore_agent_runtime_endpoint` — HTTP endpoint for invocations (gated by `create_endpoint`)

**Artifact modes** (mutually exclusive):
- **Container** — Set `container_uri` to an ECR image URI
- **Code** — Set `code_configuration` with S3 bucket, key, entry points, and Python runtime (`PYTHON_3_10` through `PYTHON_3_13`)

**Key variables:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `agent_runtime_name` | `string` | Yes | Name (pattern: `[a-zA-Z][a-zA-Z0-9_]{0,47}`) |
| `role_arn` | `string` | Yes | IAM role ARN (must trust `bedrock-agentcore.amazonaws.com`) |
| `container_uri` | `string` | No | ECR image URI |
| `code_configuration` | `object` | No | S3-based code artifact config |
| `network_mode` | `string` | No | `PUBLIC` (default) or `VPC` |
| `protocol` | `string` | No | `HTTP`, `MCP`, or `A2A` |
| `environment_variables` | `map(string)` | No | Env vars passed to the container |
| `lifecycle_configuration` | `object` | No | `idle_timeout` (60–28800s) and `max_lifetime` (60–28800s) |
| `authorizer_configuration` | `object` | No | JWT authorizer (OIDC discovery URL, audiences, clients) |
| `vpc_config` | `object` | No | Subnet and security group IDs (required when `network_mode = VPC`) |
| `request_header_allowlist` | `list(string)` | No | HTTP headers to pass through |
| `create_endpoint` | `bool` | No | Whether to create the endpoint (default `true`) |

**Outputs:** `agent_runtime_id`, `agent_runtime_arn`, `agent_runtime_version`, `workload_identity_details`, `endpoint_arn`, `endpoint_runtime_arn`

---

### `bedrock_agentcore_memory`

Creates an AgentCore Memory store with configurable memory strategies for retrieval-augmented generation.

**Resources:**
- `aws_bedrockagentcore_memory` — The memory store
- `aws_bedrockagentcore_memory_strategy` — One per strategy entry (via `for_each`)

**Strategy types:** `SEMANTIC`, `SUMMARIZATION`, `USER_PREFERENCE` (one of each type per memory, enforced by AWS).

**Key variables:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | `string` | Yes | Memory name (pattern: `[0-9a-zA-Z][-]?` up to 100 chars) |
| `event_expiry_duration` | `number` | No | Days until events expire (7–365, default 30) |
| `memory_execution_role_arn` | `string` | No | IAM role for model processing |
| `encryption_key_arn` | `string` | No | KMS key ARN (default: AWS-managed) |
| `strategies` | `map(object)` | No | Map of strategies with `name`, `type`, `namespaces`, `description` |

**Outputs:** `memory_id`, `memory_arn`, `strategy_ids`

---

### `bedrock_agentcore_identity`

Manages workload identity for inbound authentication and credential providers for outbound OAuth2/API key access.

**Resources:**
- `aws_bedrockagentcore_workload_identity` — Inbound identity with allowed OAuth2 return URLs
- `aws_bedrockagentcore_oauth2_credential_provider` — Outbound OAuth2 providers (via `for_each`)
- `aws_bedrockagentcore_api_key_credential_provider` — Outbound API key providers (via `for_each`)
- `aws_bedrockagentcore_token_vault_cmk` — Optional CMK encryption for the Token Vault

**Supported OAuth2 vendors:** `GoogleOauth2`, `GithubOauth2`, `MicrosoftOauth2`, `SlackOauth2`, `CustomOauth2` (requires `discovery_url`).

**Key variables:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | `string` | Yes | Workload identity name (3–255 chars, `[A-Za-z0-9_.-]`) |
| `allowed_oauth2_return_urls` | `list(string)` | No | Callback URLs for 3-legged auth |
| `jwt_authorizer` | `object` | No | Pass-through JWT config for the runtime module |
| `oauth2_providers` | `map(object)` | No | OAuth2 credential providers (`name`, `vendor`, `client_id`, `client_secret`, `discovery_url`) |
| `api_key_providers` | `map(object)` | No | API key providers (`name`, `api_key`) |
| `token_vault_kms_key_arn` | `string` | No | CMK for Token Vault encryption |

**Outputs:** `workload_identity_arn`, `jwt_authorizer_config`, `oauth2_provider_arns`, `api_key_provider_arns`

---

### `bedrock_agentcore_gateway`

Creates an AgentCore Gateway for agent chaining via MCP protocol, with configurable targets (Lambda or external MCP servers).

**Resources:**
- `aws_bedrockagentcore_gateway` — The gateway with authorizer, protocol, and interceptor config
- `aws_bedrockagentcore_gateway_target` — Routing targets (via `for_each`)

**Target types:**
- **Lambda** — Provide `lambda_arn` and `tool_definitions` (name, description, input schema)
- **MCP Server** — Provide an `endpoint` URL (tools discovered automatically)

**Key variables:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | `string` | Yes | Gateway name |
| `role_arn` | `string` | Yes | IAM role ARN |
| `authorizer_type` | `string` | No | `CUSTOM_JWT`, `AWS_IAM`, or `NONE` (default) |
| `protocol_type` | `string` | No | `MCP` (only supported value) |
| `protocol_configuration` | `object` | No | MCP instructions, search type (`SEMANTIC`), supported versions |
| `authorizer_configuration` | `object` | No | JWT config (when `authorizer_type = CUSTOM_JWT`) |
| `interceptor_configurations` | `list(object)` | No | Lambda interceptors (max 2) |
| `targets` | `map(object)` | No | Gateway targets with credential provider config |

**Outputs:** `gateway_id`, `gateway_arn`, `gateway_url`, `target_ids`

---

### `cognito_m2m`

Creates a Cognito User Pool configured for machine-to-machine (M2M) OAuth2 using the `client_credentials` grant. Used for Gateway → MCP Runtime outbound authentication.

**Resources:**
- `aws_cognito_user_pool` — The user pool
- `aws_cognito_user_pool_domain` — Domain for the token endpoint
- `aws_cognito_resource_server` — Resource server with custom scopes
- `aws_cognito_user_pool_client` — M2M app client with `client_credentials` flow

**Key variables:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `user_pool_name` | `string` | Yes | User pool name (also used as domain) |
| `resource_server_identifier` | `string` | Yes | Unique identifier (scope prefix) |
| `resource_server_name` | `string` | Yes | Display name |
| `client_name` | `string` | Yes | M2M app client name |
| `scopes` | `list(string)` | No | Scope names (default: `["invoke"]`) |

**Outputs:** `user_pool_id`, `user_pool_arn`, `discovery_url`, `resource_server_identifier`, `client_id`, `client_secret` (sensitive), `scopes`, `token_endpoint`

---

### `ecr`

Creates an ECR repository with image scanning, lifecycle policies, and configurable tag mutability.

**Resources:**
- `aws_ecr_repository` — The container registry
- `aws_ecr_lifecycle_policy` — Automatic image cleanup (gated by lifecycle settings)

**Lifecycle rules:**
- Expire untagged images after N days (`lifecycle_policy_untagged_days`)
- Keep only the last N images (`lifecycle_policy_max_image_count`)

**Key variables:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `repository_name` | `string` | Yes | ECR repository name |
| `image_tag_mutability` | `string` | No | `MUTABLE` (default) or `IMMUTABLE` |
| `scan_on_push` | `bool` | No | Enable image scanning (default `true`) |
| `force_delete` | `bool` | No | Allow deletion with images (default `false`) |
| `lifecycle_policy_max_image_count` | `number` | No | Max images to keep (default 10, 0 to disable) |
| `lifecycle_policy_untagged_days` | `number` | No | Expire untagged after N days (default 7, 0 to disable) |

**Outputs:** `repository_url`, `repository_arn`, `repository_name`, `registry_id`

---

### `s3`

Creates an S3 bucket with versioning, public access blocking, optional bucket policy, and optional CloudFront distribution with Origin Access Control (OAC).

**Resources:**
- `aws_s3_bucket` — The bucket
- `aws_s3_bucket_versioning` — Versioning configuration
- `aws_s3_bucket_ownership_controls` — `BucketOwnerEnforced` ownership
- `aws_s3_bucket_public_access_block` — Public access restrictions (all blocked by default)
- `aws_s3_bucket_policy` — Optional custom or CloudFront OAC policy
- `aws_cloudfront_origin_access_control` — OAC (when `enable_cloudfront = true`)
- `aws_cloudfront_distribution` — CDN distribution (when `enable_cloudfront = true`)

**Key variables:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `s3_bucket_name` | `string` | Yes | Bucket name |
| `aws_region` | `string` | Yes | AWS region |
| `project_name` | `string` | Yes | Project name |
| `environment` | `string` | Yes | Environment name |
| `s3_enable_versioning` | `bool` | No | Enable versioning (default `false`) |
| `s3_force_destroy` | `bool` | No | Allow deletion with objects (default `false`) |
| `s3_bucket_policy` | `string` | No | Custom JSON bucket policy |
| `enable_cloudfront` | `bool` | No | Create CloudFront distribution (default `false`) |

**Outputs:** `bucket_name`, `bucket_id`, `bucket_arn`, `bucket_domain_name`, `bucket_regional_domain_name`, `cloudfront_distribution_id`, `cloudfront_distribution_arn`, `cloudfront_domain_name`, `cloudfront_hosted_zone_id`

---

### `iam`

Creates an IAM role with optional managed and custom policy attachments.

**Resources:**
- `aws_iam_role` — The IAM role
- `aws_iam_role_policy_attachment` (managed) — Attaches AWS managed policies
- `aws_iam_policy` — Creates custom inline policies
- `aws_iam_role_policy_attachment` (custom) — Attaches custom policies to the role

**Key variables:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | `string` | Yes | Role name |
| `assume_role_policy` | `string` | Yes | Trust policy JSON |
| `project_name` | `string` | Yes | Project name |
| `environment` | `string` | Yes | Environment name |
| `managed_policies` | `list(string)` | No | AWS managed policy ARNs |
| `custom_policies` | `list(object)` | No | Custom policies (`name`, `description`, `policy` JSON) |

**Outputs:** `arn`, `id`, `name`, `custom_policy_arns`, `custom_policy_ids`

---

## IAM Policy Templates

Policy templates live in `iam/policies/` and are consumed via `templatefile()`. All follow least-privilege principles.

| Policy | Template Variables | Purpose |
|--------|--------------------|---------|
| `agentcore_ecr.json` | `aws_region`, `aws_account_id` | Pull container images from ECR |
| `agentcore_s3.json` | `agent_code_bucket_arn` | Read code artifacts from S3 |
| `agentcore_logs.json` | `aws_region`, `aws_account_id` | CloudWatch Logs, X-Ray traces, CloudWatch metrics |
| `agentcore_bedrock.json` | `aws_region`, `aws_account_id` | Invoke Bedrock foundation models |
| `agentcore_workload_identity.json` | `aws_region`, `aws_account_id` | Manage workload identities, retrieve OAuth2 tokens, access Secrets Manager |
| `agentcore_memory_dataplane.json` | *(none)* | Retrieve/create memory records and events |
| `agentcore_invoke_gateway.json` | `aws_region`, `aws_account_id` | Invoke AgentCore Gateway |

**Trust policy:** `iam/trust_policies/agentcore_runtime.json` — Allows `bedrock-agentcore.amazonaws.com` to assume the role.

---

## Dev Environment Composition

The `environments/dev/main.tf` composes the modules in this order:

1. **S3** (`agent_code_bucket`) — Code artifact storage with versioning
2. **ECR** (`agent_ecr`) — Container registry with scanning and lifecycle policies
3. **IAM** (`agentcore_runtime_role`) — Runtime role with 7 custom policies (ECR, S3, Logs, Identity, Bedrock, Memory, Gateway)
4. **Runtime** (`agentcore_runtime`) — Gated by `create_runtime`; supports container or code mode; auto-injects `MEMORY_ID` and Google Drive env vars
5. **IAM** (`agentcore_memory_role`) — Memory role with Bedrock model access (gated by `create_memory`)
6. **Memory** (`agentcore_memory`) — Gated by `create_memory`; configurable strategies
7. **Identity** (`agentcore_identity`) — Gated by `create_identity`; workload identity, OAuth2 providers, API key providers

---

## Terraform Workflow

Run these commands from the environment directory (e.g., `infrastructure/environments/dev`):

```bash
# Initialize and download providers/modules
terraform init

# Check formatting and validity
terraform fmt -recursive
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy resources (caution: deletes everything in the environment)
terraform destroy
```

## Troubleshooting

- If you change providers or modules, run `terraform init -upgrade` to update.
- If you encounter state errors, remove `.terraform/` and re-run `terraform init`.
- Use `terraform state list` and `terraform state show <resource>` to inspect current state.
