# Infrastructure (AWS)

This directory contains the Terraform code for the project's AWS infrastructure. The `infrastructure` folder organizes reusable modules and deployable environments.

## Directory Structure

- `modules/` — Reusable Terraform modules (one per service). Each module contains `main.tf`, `variables.tf`, `outputs.tf` and helper files.
- `environments/` — Deployable environments (e.g., `dev/`). Each environment has its own configuration (`main.tf`, `provider.tf`, `terraform.tfvars`, `.env`).

## Available Modules

| Module | Description |
|--------|-------------|
| `s3/` | S3 buckets with access policies, versioning, and optional static hosting |
| `ecr/` | ECR repositories with image scanning, lifecycle policies, and tag mutability |
| `iam/` | IAM roles with assume role policies, managed and custom policy attachments |
| `bedrock_agentcore_runtime/` | AgentCore Runtime and Endpoint (container or code deployment, networking, protocol, lifecycle, JWT auth) |
| `bedrock_agentcore_memory/` | AgentCore Memory store with strategies (semantic, summarization, user preference) |
| `bedrock_agentcore_identity/` | Workload identity, JWT authorizer, OAuth2 credential providers |
| `bedrock_agentcore_gateway/` | AgentCore Gateway for agent chaining with target routing |
| `cognito_m2m/` | Cognito machine-to-machine authentication |

Modules are composable: environments instantiate them with appropriate variables.

## Environments

Environments live under `environments/`. Currently available:

- `dev/` — Development environment (`provider.tf`, `main.tf`, `terraform.tfvars`, `.env`)

Each environment maintains its own variables and configuration in `.env` and `terraform.tfvars` files.

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

## Important Files

| File | Purpose |
|------|---------|
| `terraform.tfvars` | Environment-specific variable values |
| `.env` | Environment variables (do not commit secrets) |
| `provider.tf` | Provider configuration (region, profile, backend) |
| `variables.tf` / `outputs.tf` | Defined in each module for clarity and reusability |

## Troubleshooting

- If you change providers or modules, run `terraform init -upgrade` to update.
- If you encounter state errors, remove `.terraform/` and re-run `terraform init`.
- Use `terraform state list` and `terraform state show <resource>` to inspect current state.
