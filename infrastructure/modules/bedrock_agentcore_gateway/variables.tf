################################################################################
# Required Variables
################################################################################

variable "name" {
  description = "Name of the AgentCore Gateway. Must match pattern: [0-9a-zA-Z][-]? repeated up to 100 times."
  type        = string

  validation {
    condition     = can(regex("^([0-9a-zA-Z][-]?){1,100}$", var.name))
    error_message = "name must match pattern ^([0-9a-zA-Z][-]?){1,100}$."
  }
}

variable "role_arn" {
  description = "ARN of the IAM role that the gateway assumes."
  type        = string
}

variable "authorizer_type" {
  description = "Authorizer type for the gateway. Valid values: CUSTOM_JWT, AWS_IAM, NONE."
  type        = string
  default     = "NONE"

  validation {
    condition     = contains(["CUSTOM_JWT", "AWS_IAM", "NONE"], var.authorizer_type)
    error_message = "authorizer_type must be one of: CUSTOM_JWT, AWS_IAM, NONE."
  }
}

variable "protocol_type" {
  description = "Protocol type for the gateway. Currently only MCP is supported."
  type        = string
  default     = "MCP"

  validation {
    condition     = contains(["MCP"], var.protocol_type)
    error_message = "protocol_type must be MCP."
  }
}

################################################################################
# Optional Variables
################################################################################

variable "description" {
  description = "Description of the gateway (max 200 chars)."
  type        = string
  default     = null
}

variable "exception_level" {
  description = "Exception level for the gateway. Valid values: DEBUG, or null for default."
  type        = string
  default     = null

  validation {
    condition     = var.exception_level == null || contains(["DEBUG"], var.exception_level)
    error_message = "exception_level must be DEBUG or null."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption. If null, AWS-managed encryption is used."
  type        = string
  default     = null
}

variable "authorizer_configuration" {
  description = <<-EOT
    JWT-based authorization configuration (used when authorizer_type = CUSTOM_JWT).
    - discovery_url: OIDC discovery URL
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

variable "protocol_configuration" {
  description = <<-EOT
    MCP protocol configuration for the gateway.
    - instructions: instructions for the gateway (max 2048 chars)
    - search_type: search type (SEMANTIC or null)
    - supported_versions: list of supported MCP versions
  EOT
  type = object({
    instructions       = optional(string)
    search_type        = optional(string)
    supported_versions = optional(list(string))
  })
  default = null

  validation {
    condition     = var.protocol_configuration == null || try(var.protocol_configuration.search_type, null) == null || contains(["SEMANTIC"], try(var.protocol_configuration.search_type, ""))
    error_message = "protocol_configuration.search_type must be SEMANTIC or null."
  }
}

variable "interceptor_configurations" {
  description = <<-EOT
    List of interceptor configurations for the gateway (max 2).
    Each item:
    - interception_points: list of interception point strings (1-2 items)
    - interceptor: object with interceptor type config (e.g. lambda_arn)
    - input_configuration: optional input configuration (pass_request_headers)
  EOT
  type = list(object({
    interception_points = list(string)
    interceptor = object({
      lambda_arn = string
    })
    input_configuration = optional(object({
      pass_request_headers = optional(bool, false)
    }))
  }))
  default = []
}

variable "tags" {
  description = "Key-value map of resource tags."
  type        = map(string)
  default     = {}
}

################################################################################
# Gateway Target Variables
################################################################################

variable "targets" {
  description = <<-EOT
    Map of gateway targets to create. Each key is used as the for_each key.
    Provide exactly one of lambda_configuration or mcp_server_configuration.

    Each value:
    - name: target name
    - description: optional description
    - lambda_configuration: Lambda-based MCP target (requires tool_definitions)
    - mcp_server_configuration: external MCP server target (tools discovered automatically)
    - credential_provider_configuration: optional credential config
  EOT
  type = map(object({
    name        = string
    description = optional(string)

    # Lambda target — provide tool definitions, gateway invokes Lambda
    lambda_configuration = optional(object({
      lambda_arn = string
      tool_definitions = list(object({
        name              = string
        description       = string
        input_schema_type = optional(string, "object")
      }))
    }))

    # MCP Server target — gateway connects to an external MCP server endpoint
    mcp_server_configuration = optional(object({
      endpoint = string
    }))

    credential_provider_configuration = optional(object({
      gateway_iam_role = optional(bool, false)
      oauth = optional(object({
        provider_arn      = string
        scopes            = optional(list(string), [])
        custom_parameters = optional(map(string), {})
      }))
      api_key = optional(object({
        provider_arn              = string
        credential_location       = optional(string, "HEADER")
        credential_parameter_name = optional(string)
        credential_prefix         = optional(string)
      }))
    }))
  }))
  default = {}
}
