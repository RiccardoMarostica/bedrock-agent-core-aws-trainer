################################################################################
# Required Variables
################################################################################

variable "agent_runtime_name" {
  description = "Name of the AgentCore agent runtime. Must match pattern: [a-zA-Z][a-zA-Z0-9_]{0,47}"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,47}$", var.agent_runtime_name))
    error_message = "agent_runtime_name must start with a letter and contain only alphanumeric characters and underscores (max 48 chars)."
  }
}

variable "role_arn" {
  description = "ARN of the IAM role that the agent runtime assumes. The role must trust bedrock-agentcore.amazonaws.com."
  type        = string
}

variable "network_mode" {
  description = "Network mode for the agent runtime. Valid values: PUBLIC, VPC."
  type        = string
  default     = "PUBLIC"

  validation {
    condition     = contains(["PUBLIC", "VPC"], var.network_mode)
    error_message = "network_mode must be either PUBLIC or VPC."
  }
}

################################################################################
# Artifact Configuration (exactly one must be provided)
################################################################################

variable "container_uri" {
  description = "URI of the container image in Amazon ECR. Mutually exclusive with code_configuration."
  type        = string
  default     = null
}

variable "code_configuration" {
  description = <<-EOT
    Code-based artifact configuration. Mutually exclusive with container_uri.
    - entry_points: list of entry point files (1-2 elements, e.g. ["main.py"])
    - runtime: execution runtime (PYTHON_3_10, PYTHON_3_11, PYTHON_3_12, PYTHON_3_13)
    - s3_bucket: S3 bucket containing the source code ZIP
    - s3_prefix: S3 key of the source code ZIP
    - s3_version_id: (optional) S3 object version ID
  EOT
  type = object({
    entry_points  = list(string)
    runtime       = string
    s3_bucket     = string
    s3_prefix     = string
    s3_version_id = optional(string)
  })
  default = null

  validation {
    condition     = var.code_configuration == null || contains(["PYTHON_3_10", "PYTHON_3_11", "PYTHON_3_12", "PYTHON_3_13"], try(var.code_configuration.runtime, ""))
    error_message = "code_configuration.runtime must be one of: PYTHON_3_10, PYTHON_3_11, PYTHON_3_12, PYTHON_3_13."
  }
}

################################################################################
# Optional Variables
################################################################################

variable "description" {
  description = "Description of the agent runtime (max 1200 chars)."
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "Map of environment variables to pass to the agent runtime container."
  type        = map(string)
  default     = {}
}

variable "protocol" {
  description = "Communication protocol for the agent runtime. Valid values: HTTP, MCP, A2A."
  type        = string
  default     = null

  validation {
    condition     = var.protocol == null || contains(["HTTP", "MCP", "A2A"], var.protocol)
    error_message = "protocol must be one of: HTTP, MCP, A2A."
  }
}

variable "lifecycle_configuration" {
  description = <<-EOT
    Lifecycle settings for the agent runtime sessions.
    - idle_timeout: idle session timeout in seconds (60-28800, default 900)
    - max_lifetime: max instance lifetime in seconds (60-28800, default 28800)
  EOT
  type = object({
    idle_timeout = optional(number, 900)
    max_lifetime = optional(number, 28800)
  })
  default = null

  validation {
    condition = var.lifecycle_configuration == null || (
      var.lifecycle_configuration.idle_timeout >= 60 &&
      var.lifecycle_configuration.idle_timeout <= 28800 &&
      var.lifecycle_configuration.max_lifetime >= 60 &&
      var.lifecycle_configuration.max_lifetime <= 28800 &&
      var.lifecycle_configuration.idle_timeout <= var.lifecycle_configuration.max_lifetime
    )
    error_message = "idle_timeout and max_lifetime must be between 60 and 28800 seconds, and idle_timeout <= max_lifetime."
  }
}

variable "authorizer_configuration" {
  description = <<-EOT
    JWT-based authorization configuration for incoming requests.
    - discovery_url: OIDC discovery URL (must end with .well-known/openid-configuration)
    - allowed_audiences: list of allowed JWT audience values
    - allowed_clients: list of allowed JWT client IDs
  EOT
  type = object({
    discovery_url     = string
    allowed_audiences = optional(list(string), [])
    allowed_clients   = optional(list(string), [])
  })
  default = null
}

variable "vpc_config" {
  description = <<-EOT
    VPC configuration (required when network_mode is VPC).
    - subnet_ids: list of subnet IDs
    - security_group_ids: list of security group IDs
  EOT
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "request_header_allowlist" {
  description = "List of HTTP request headers allowed to pass through to the runtime."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Key-value map of resource tags."
  type        = map(string)
  default     = {}
}

################################################################################
# Runtime Endpoint Variables
################################################################################

variable "create_endpoint" {
  description = "Whether to create an AgentCore Runtime Endpoint for this runtime."
  type        = bool
  default     = true
}

variable "endpoint_name" {
  description = "Name of the runtime endpoint. Defaults to agent_runtime_name if not set."
  type        = string
  default     = null
}

variable "endpoint_description" {
  description = "Description of the runtime endpoint."
  type        = string
  default     = null
}

variable "endpoint_agent_runtime_version" {
  description = "Specific agent runtime version to pin the endpoint to. If null, uses the latest version."
  type        = string
  default     = null
}

variable "endpoint_tags" {
  description = "Tags for the runtime endpoint. Merged with var.tags."
  type        = map(string)
  default     = {}
}
