################################################################################
# Global
################################################################################

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project name used for naming and tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)."
  type        = string
}

################################################################################
# S3 — Agent Code Artifact Bucket
################################################################################

variable "agent_code_bucket_name" {
  description = "Name of the S3 bucket that stores agent runtime code artifacts."
  type        = string
}

################################################################################
# AgentCore Runtime
################################################################################

variable "create_runtime" {
  description = "Whether to create the AgentCore Runtime. Set to false on first apply (ECR image must exist first)."
  type        = bool
  default     = false
}

variable "agent_runtime_name" {
  description = "Name of the Bedrock AgentCore agent runtime."
  type        = string
}

variable "agent_runtime_description" {
  description = "Description of the agent runtime."
  type        = string
  default     = ""
}

variable "agent_runtime_protocol" {
  description = "Communication protocol: HTTP, MCP, or A2A."
  type        = string
  default     = "HTTP"
}

variable "agent_runtime_network_mode" {
  description = "Network mode: PUBLIC or VPC."
  type        = string
  default     = "PUBLIC"
}

variable "agent_runtime_environment_variables" {
  description = "Environment variables passed to the agent runtime."
  type        = map(string)
  default     = {}
}

variable "agent_runtime_lifecycle" {
  description = "Lifecycle settings: idle_timeout and max_lifetime in seconds."
  type = object({
    idle_timeout = optional(number, 900)
    max_lifetime = optional(number, 28800)
  })
  default = null
}

################################################################################
# ECR
################################################################################

variable "ecr_repository_name" {
  description = "Name of the ECR repository for the agent container image."
  type        = string
}

################################################################################
# Agent Artifact — choose one mode
################################################################################

variable "agent_use_container" {
  description = "Set to true to deploy via ECR container, false for S3 code ZIP."
  type        = bool
  default     = true
}

variable "agent_container_image_tag" {
  description = "Container image tag to deploy (e.g. latest, v1.0.0)."
  type        = string
  default     = "latest"
}

variable "agent_code_entry_points" {
  description = "Entry point files for code-based artifact (e.g. [\"main.py\"])."
  type        = list(string)
  default     = []
}

variable "agent_code_runtime" {
  description = "Python runtime for code-based artifact: PYTHON_3_10 | PYTHON_3_11 | PYTHON_3_12 | PYTHON_3_13."
  type        = string
  default     = "PYTHON_3_13"
}

variable "agent_code_s3_key" {
  description = "S3 object key of the agent code ZIP inside the artifact bucket."
  type        = string
  default     = ""
}

################################################################################
# AgentCore Memory
################################################################################

variable "create_memory" {
  description = "Whether to create the AgentCore Memory."
  type        = bool
  default     = false
}

variable "memory_name" {
  description = "Name of the Bedrock AgentCore Memory."
  type        = string
  default     = ""
}

variable "memory_description" {
  description = "Description of the memory."
  type        = string
  default     = ""
}

variable "memory_event_expiry_duration" {
  description = "Number of days after which memory events expire (7–365)."
  type        = number
  default     = 30
}

variable "memory_strategies" {
  description = "Map of memory strategies. Each entry: name, type (SEMANTIC|SUMMARIZATION|USER_PREFERENCE), namespaces, optional description."
  type = map(object({
    name        = string
    type        = string
    namespaces  = set(string)
    description = optional(string)
  }))
  default = {}
}

################################################################################
# AgentCore Identity
################################################################################

variable "create_identity" {
  description = "Whether to create the AgentCore Identity resources (workload identity and credential providers)."
  type        = bool
  default     = false
}

variable "identity_name" {
  description = "Name of the AgentCore Workload Identity. Pattern: [A-Za-z0-9_.-]+, 3-255 chars."
  type        = string
  default     = ""
}

variable "identity_allowed_oauth2_return_urls" {
  description = "List of OAuth2 callback URLs allowed for 3-legged flows on the workload identity."
  type        = list(string)
  default     = []
}

variable "identity_jwt_authorizer" {
  description = <<-EOT
    Optional JWT authorizer configuration for inbound auth.
    Surfaced as jwt_authorizer_config output to wire into the runtime module.
    Fields: discovery_url (required), allowed_clients, allowed_audiences, allowed_scopes.
  EOT
  type = object({
    discovery_url     = string
    allowed_clients   = optional(list(string), [])
    allowed_audiences = optional(list(string), [])
    allowed_scopes    = optional(list(string), [])
  })
  default = null
}

variable "identity_oauth2_providers" {
  description = "Map of OAuth2 credential providers. Each entry: name, vendor, client_id, client_secret, optional discovery_url (required for CustomOauth2)."
  type = map(object({
    name          = string
    vendor        = string
    client_id     = string
    client_secret = string
    discovery_url = optional(string)
  }))
  default = {}
}

variable "identity_api_key_providers" {
  description = "Map of API key credential providers. Each entry: name, api_key."
  type = map(object({
    name    = string
    api_key = string
  }))
  default = {}
}

variable "identity_token_vault_kms_key_arn" {
  description = "Optional KMS key ARN for CMK encryption of the account-level Token Vault. When null, AWS-managed encryption is used."
  type        = string
  default     = null
}

################################################################################
# Google Drive Integration
################################################################################

variable "google_oauth2_provider_name" {
  description = "Name of the Google OAuth2 credential provider (used by the agent to request access tokens)."
  type        = string
  default     = ""
}

variable "google_drive_folder_name" {
  description = "Google Drive folder name where session files are stored."
  type        = string
  default     = "AgentCoreSessions"
}

variable "google_oauth2_callback_url" {
  description = "OAuth2 callback URL returned by the credential provider creation. Set after first apply."
  type        = string
  default     = ""
}

variable "google_oauth2_return_url" {
  description = "URL of the local OAuth2 callback server that handles session binding via CompleteResourceTokenAuth."
  type        = string
  default     = ""
}
