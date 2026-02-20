################################################################################
# Data Sources
################################################################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


################################################################################
# S3 — Agent Code Artifact Bucket
################################################################################

module "agent_code_bucket" {
  source = "../../modules/s3"

  aws_region   = var.aws_region
  project_name = var.project_name
  environment  = var.environment

  s3_bucket_name       = var.agent_code_bucket_name
  s3_enable_versioning = true
  s3_force_destroy     = true # dev only — easy cleanup
}

################################################################################
# ECR — Agent Container Registry
################################################################################

module "agent_ecr" {
  source = "../../modules/ecr"

  repository_name                  = var.ecr_repository_name
  image_tag_mutability             = "MUTABLE"
  scan_on_push                     = true
  force_delete                     = true # dev only
  lifecycle_policy_max_image_count = 10
  lifecycle_policy_untagged_days   = 7

  tags = local.common_tags
}

################################################################################
# IAM — AgentCore Runtime Role
################################################################################

module "agentcore_runtime_role" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment

  name        = "${var.project_name}-${var.environment}-agentcore-runtime"
  description = "IAM role assumed by Bedrock AgentCore Runtime"

  assume_role_policy = templatefile("../../../iam/trust_policies/agentcore_runtime.json", {})

  custom_policies = [
    {
      name        = "${var.project_name}-${var.environment}-agentcore-ecr"
      description = "Allow AgentCore to pull container images from ECR"
      policy = templatefile("../../../iam/policies/agentcore_ecr.json", {
        aws_region     = local.region
        aws_account_id = local.account_id
      })
    },
    {
      name        = "${var.project_name}-${var.environment}-agentcore-s3"
      description = "Allow AgentCore to read code artifacts from S3"
      policy = templatefile("../../../iam/policies/agentcore_s3.json", {
        agent_code_bucket_arn = module.agent_code_bucket.bucket_arn
      })
    },
    {
      name        = "${var.project_name}-${var.environment}-agentcore-logs"
      description = "Allow AgentCore to write CloudWatch logs"
      policy = templatefile("../../../iam/policies/agentcore_logs.json", {
        aws_region     = local.region
        aws_account_id = local.account_id
      })
    },
    {
      name        = "${var.project_name}-${var.environment}-agentcore-identity"
      description = "Allow AgentCore Runtime to manage workload identities and retrieve OAuth2 tokens"
      policy = templatefile("../../../iam/policies/agentcore_workload_identity.json", {
        aws_region     = local.region
        aws_account_id = local.account_id
      })
    },
    {
      name        = "${var.project_name}-${var.environment}-agentcore-bedrock"
      description = "Allow AgentCore to invoke Bedrock models"
      policy = templatefile("../../../iam/policies/agentcore_bedrock.json", {
        aws_region     = local.region
        aws_account_id = local.account_id
      })
    },
    {
      name        = "${var.project_name}-${var.environment}-agentcore-memory-dataplane"
      description = "Allow AgentCore Runtime to read and write memory records"
      policy      = templatefile("../../../iam/policies/agentcore_memory_dataplane.json", {})
    },
    {
      name        = "${var.project_name}-${var.environment}-agentcore-invoke-gateway"
      description = "Allow AgentCore Runtime to invoke the AgentCore Gateway"
      policy = templatefile("../../../iam/policies/agentcore_invoke_gateway.json", {
        aws_region     = local.region
        aws_account_id = local.account_id
      })
    }
  ]
}

################################################################################
# Bedrock AgentCore — Agent Runtime
#
# Gated by var.create_runtime (default false).
# First apply creates ECR + IAM + S3, then push the image, then set
# create_runtime = true and apply again.
################################################################################

module "agentcore_runtime" {
  count  = var.create_runtime ? 1 : 0
  source = "../../modules/bedrock_agentcore_runtime"

  agent_runtime_name = var.agent_runtime_name
  role_arn           = module.agentcore_runtime_role.arn
  description        = var.agent_runtime_description

  # Artifact — container mode
  container_uri = local.use_container ? "${module.agent_ecr.repository_url}:${var.agent_container_image_tag}" : null

  # Artifact — code mode
  code_configuration = local.use_code ? {
    entry_points  = var.agent_code_entry_points
    runtime       = var.agent_code_runtime
    s3_bucket     = module.agent_code_bucket.bucket_name
    s3_prefix     = var.agent_code_s3_key
    s3_version_id = null
  } : null

  # Network & protocol
  network_mode = var.agent_runtime_network_mode
  protocol     = var.agent_runtime_protocol

  # Runtime settings
  environment_variables = merge(
    var.agent_runtime_environment_variables,
    {
      MEMORY_ID = length(module.agentcore_memory) > 0 ? module.agentcore_memory[0].memory_id : ""
    },
    var.google_oauth2_provider_name != "" ? {
      GOOGLE_OAUTH2_PROVIDER_NAME = var.google_oauth2_provider_name
      GOOGLE_DRIVE_FOLDER_NAME    = var.google_drive_folder_name
      OAUTH2_RETURN_URL           = var.google_oauth2_return_url
    } : {}
  )
  lifecycle_configuration = var.agent_runtime_lifecycle

  # Endpoint
  create_endpoint = true
}

# ################################################################################
# # AWS Docs MCP Server — ECR Repository
# ################################################################################

# module "aws_docs_mcp_ecr" {
#   source = "../../modules/ecr"

#   repository_name                  = var.aws_docs_mcp_ecr_repository_name
#   image_tag_mutability             = "MUTABLE"
#   scan_on_push                     = true
#   force_delete                     = true # dev only
#   lifecycle_policy_max_image_count = 10
#   lifecycle_policy_untagged_days   = 7

#   tags = local.common_tags
# }

# ################################################################################
# # AWS Docs MCP Server — IAM Role
# ################################################################################

# module "aws_docs_mcp_runtime_role" {
#   count  = var.create_aws_docs_mcp_runtime ? 1 : 0
#   source = "../../modules/iam"

#   project_name = var.project_name
#   environment  = var.environment

#   name        = "${var.project_name}-${var.environment}-aws-docs-mcp-runtime"
#   description = "IAM role assumed by Bedrock AgentCore Runtime for AWS Docs MCP Server"

#   assume_role_policy = templatefile("../../../iam/trust_policies/agentcore_runtime.json", {})

#   custom_policies = [
#     {
#       name        = "${var.project_name}-${var.environment}-aws-docs-mcp-ecr"
#       description = "Allow AgentCore to pull AWS Docs MCP Server image from ECR"
#       policy = templatefile("../../../iam/policies/agentcore_ecr.json", {
#         aws_region     = local.region
#         aws_account_id = local.account_id
#       })
#     },
#     {
#       name        = "${var.project_name}-${var.environment}-aws-docs-mcp-logs"
#       description = "Allow AgentCore to write CloudWatch logs for AWS Docs MCP Server"
#       policy = templatefile("../../../iam/policies/agentcore_logs.json", {
#         aws_region     = local.region
#         aws_account_id = local.account_id
#       })
#     },
#     {
#       name        = "${var.project_name}-${var.environment}-aws-docs-mcp-identity"
#       description = "Allow AgentCore Runtime to get workload access tokens"
#       policy = templatefile("../../../iam/policies/agentcore_workload_identity.json", {
#         aws_region     = local.region
#         aws_account_id = local.account_id
#         runtime_name   = var.aws_docs_mcp_runtime_name
#       })
#     }
#   ]
# }

# ################################################################################
# # AWS Docs MCP Server — AgentCore Runtime
# #
# # Gated by var.create_aws_docs_mcp_runtime (default false).
# # Steps:
# #   1. Set create_aws_docs_mcp_runtime = true and apply → creates ECR + IAM
# #   2. Build and push the image:  cd mcp/aws-documentation-mcp-server && make build-push
# #   3. Apply again → creates the AgentCore Runtime
# ################################################################################

# module "aws_docs_mcp_runtime" {
#   count  = var.create_aws_docs_mcp_runtime ? 1 : 0
#   source = "../../modules/bedrock_agentcore_runtime"

#   agent_runtime_name = var.aws_docs_mcp_runtime_name
#   role_arn           = module.aws_docs_mcp_runtime_role[0].arn
#   description        = var.aws_docs_mcp_runtime_description

#   container_uri = "${module.aws_docs_mcp_ecr.repository_url}:${var.aws_docs_mcp_container_image_tag}"

#   network_mode = "PUBLIC"
#   protocol     = "MCP"

#   environment_variables = {
#     FASTMCP_LOG_LEVEL           = "WARNING"
#     FASTMCP_HOST                = "0.0.0.0"
#     FASTMCP_PORT                = "8000"
#     FASTMCP_STATELESS_HTTP      = "true"
#     AWS_DOCUMENTATION_PARTITION = "aws"
#   }

#   # JWT authorizer — validates tokens issued by Cognito M2M pool
#   # Note: Cognito client_credentials tokens use the client_id claim (not aud),
#   # so we set allowed_audiences to the client_id value.
#   authorizer_configuration = var.create_gateway ? {
#     discovery_url     = module.cognito_mcp_m2m[0].discovery_url
#     allowed_clients   = [module.cognito_mcp_m2m[0].client_id]
#     allowed_audiences = [module.cognito_mcp_m2m[0].client_id]
#   } : null

#   create_endpoint = true
# }

# ################################################################################
# # IAM — AgentCore Gateway Role
# ################################################################################

# module "agentcore_gateway_role" {
#   count  = var.create_gateway ? 1 : 0
#   source = "../../modules/iam"

#   project_name = var.project_name
#   environment  = var.environment

#   name        = "${var.project_name}-${var.environment}-agentcore-gateway"
#   description = "IAM role assumed by Bedrock AgentCore Gateway"

#   assume_role_policy = templatefile("../../../iam/trust_policies/agentcore_runtime.json", {})

#   custom_policies = [
#     {
#       name        = "${var.project_name}-${var.environment}-agentcore-gateway-invoke"
#       description = "Allow Gateway to invoke AgentCore Runtimes (MCP server targets)"
#       policy = templatefile("../../../iam/policies/agentcore_gateway.json", {
#         aws_region     = local.region
#         aws_account_id = local.account_id
#       })
#     },
#     {
#       name        = "${var.project_name}-${var.environment}-agentcore-gateway-logs"
#       description = "Allow Gateway to write CloudWatch logs"
#       policy = templatefile("../../../iam/policies/agentcore_logs.json", {
#         aws_region     = local.region
#         aws_account_id = local.account_id
#       })
#     },
#     {
#       name        = "${var.project_name}-${var.environment}-agentcore-gateway-oauth"
#       description = "Allow Gateway to retrieve OAuth tokens and secrets for outbound auth"
#       policy = templatefile("../../../iam/policies/agentcore_gateway_oauth.json", {
#         aws_region     = local.region
#         aws_account_id = local.account_id
#         gateway_name   = var.gateway_name
#       })
#     }
#   ]
# }

# ################################################################################
# # Cognito M2M — OAuth2 for Gateway → MCP Runtime auth
# #
# # Creates a Cognito User Pool with a resource server and M2M app client.
# # The client_credentials grant is used by the Gateway (via Identity OAuth2
# # credential provider) to obtain a JWT that the MCP Runtime validates.
# ################################################################################

# module "cognito_mcp_m2m" {
#   count  = var.create_gateway ? 1 : 0
#   source = "../../modules/cognito_m2m"

#   user_pool_name             = "${var.project_name}-${var.environment}-mcp-m2m"
#   resource_server_identifier = "mcp-runtime"
#   resource_server_name       = "MCP Runtime"
#   client_name                = "${var.project_name}-${var.environment}-gateway-client"
#   scopes                     = ["invoke"]

#   tags = local.common_tags
# }

# ################################################################################
# # Wait for MCP Runtime to become READY before creating Gateway targets.
# # The runtime needs time to start up after creation/update, and the Gateway
# # target creation triggers an immediate sync (tools/list) against the runtime.
# ################################################################################

# resource "time_sleep" "wait_for_mcp_runtime" {
#   count = var.create_aws_docs_mcp_runtime && var.create_gateway ? 1 : 0

#   depends_on      = [module.aws_docs_mcp_runtime]
#   create_duration = "120s"
# }

# ################################################################################
# # Bedrock AgentCore — Gateway
# #
# # Gated by var.create_gateway (default false).
# # The AWS Docs MCP Runtime endpoint URL is derived automatically from the
# # runtime ARN — no manual copy-paste needed.
# ################################################################################
# module "agentcore_gateway" {
#   count  = var.create_gateway ? 1 : 0
#   source = "../../modules/bedrock_agentcore_gateway"

#   depends_on = [time_sleep.wait_for_mcp_runtime]

#   name            = var.gateway_name
#   role_arn        = module.agentcore_gateway_role[0].arn
#   authorizer_type = var.gateway_authorizer_type
#   description     = var.gateway_description
#   exception_level = var.gateway_exception_level

#   protocol_configuration = var.gateway_protocol_configuration

#   targets = {
#     aws_docs = {
#       name        = "aws-docs-mcp"
#       description = "AWS Documentation MCP Server running on AgentCore Runtime"
#       mcp_server_configuration = {
#         endpoint = local.aws_docs_mcp_invocation_endpoint
#       }
#       credential_provider_configuration = var.create_identity ? {
#         oauth = {
#           provider_arn = module.agentcore_identity[0].oauth2_provider_arns["mcp_runtime"]
#           scopes       = module.cognito_mcp_m2m[0].scopes
#         }
#       } : null
#     }
#   }

#   tags = local.common_tags
# }

################################################################################
# IAM — AgentCore Memory Role
################################################################################

module "agentcore_memory_role" {
  count  = var.create_memory ? 1 : 0
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment

  name        = "${var.project_name}-${var.environment}-agentcore-memory"
  description = "IAM role assumed by Bedrock AgentCore Memory"

  assume_role_policy = templatefile("../../../iam/trust_policies/agentcore_runtime.json", {})

  custom_policies = [
    {
      name        = "${var.project_name}-${var.environment}-agentcore-memory-bedrock"
      description = "Allow AgentCore Memory to invoke Bedrock foundation models"
      policy = templatefile("../../../iam/policies/agentcore_bedrock.json", {
        aws_region     = local.region
        aws_account_id = local.account_id
      })
    }
  ]
}

################################################################################
# Bedrock AgentCore — Memory
#
# Gated by var.create_memory (default false).
# Apply with create_memory = true to create the memory store and strategies.
################################################################################

module "agentcore_memory" {
  count  = var.create_memory ? 1 : 0
  source = "../../modules/bedrock_agentcore_memory"

  name                      = var.memory_name
  event_expiry_duration     = var.memory_event_expiry_duration
  description               = var.memory_description
  memory_execution_role_arn = module.agentcore_memory_role[0].arn
  strategies                = var.memory_strategies

  tags = local.common_tags
}

################################################################################
# Bedrock AgentCore — Identity
#
# Gated by var.create_identity (default false).
# Creates: workload identity, OAuth2 credential providers, API key credential
# providers, and optionally a Token Vault CMK.
#
# To wire the JWT authorizer into the runtime, set identity_jwt_authorizer and
# pass module.agentcore_identity[0].jwt_authorizer_config to the runtime's
# authorizer_configuration variable.
################################################################################

module "agentcore_identity" {
  count  = var.create_identity ? 1 : 0
  source = "../../modules/bedrock_agentcore_identity"

  name = var.identity_name
  allowed_oauth2_return_urls = compact(concat(
    var.identity_allowed_oauth2_return_urls,
    [var.google_oauth2_callback_url],
    [var.google_oauth2_return_url]
  ))
  jwt_authorizer          = var.identity_jwt_authorizer
  token_vault_kms_key_arn = var.identity_token_vault_kms_key_arn

  # OAuth2 credential providers:
  # - Gateway (Cognito M2M) is included only when create_gateway = true
  # - Additional providers (e.g. Google Drive) come from var.identity_oauth2_providers
  # oauth2_providers = merge(
  #   var.create_gateway ? {
  #     mcp_runtime = {
  #       name          = "${var.project_name}-${var.environment}-mcp-runtime"
  #       vendor        = "CustomOauth2"
  #       client_id     = module.cognito_mcp_m2m[0].client_id
  #       client_secret = module.cognito_mcp_m2m[0].client_secret
  #       discovery_url = module.cognito_mcp_m2m[0].discovery_url
  #     }
  #   } : {},
  #   var.identity_oauth2_providers
  # )

  oauth2_providers  = var.identity_oauth2_providers
  api_key_providers = var.identity_api_key_providers

  tags = local.common_tags
}
