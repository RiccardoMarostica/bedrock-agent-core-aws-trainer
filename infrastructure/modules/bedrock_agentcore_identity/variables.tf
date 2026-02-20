################################################################################
# Required Variables
################################################################################

variable "name" {
  description = "Name of the AgentCore Workload Identity. Must match pattern: [A-Za-z0-9_.-]+, 3-255 chars."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.\\-]{3,255}$", var.name))
    error_message = "name must be 3-255 characters and match [A-Za-z0-9_.-]."
  }
}

################################################################################
# Inbound Auth — Workload Identity
################################################################################

variable "allowed_oauth2_return_urls" {
  description = "List of OAuth2 callback URLs allowed for 3-legged (user-delegated) auth flows."
  type        = list(string)
  default     = []
}

################################################################################
# Inbound Auth — JWT Authorizer (pass-through config, no resource created)
################################################################################

variable "jwt_authorizer" {
  description = <<-EOT
    Optional JWT authorizer configuration. When set, this value is surfaced verbatim
    as the jwt_authorizer_config output for consumption by the runtime module's
    authorizer_configuration variable. No AWS resource is created.
    - discovery_url: OIDC well-known URL (must end with .well-known/openid-configuration)
    - allowed_clients: list of allowed JWT client_id claim values
    - allowed_audiences: list of allowed JWT aud claim values
    - allowed_scopes: list of allowed JWT scope claim values
  EOT
  type = object({
    discovery_url     = string
    allowed_clients   = optional(list(string), [])
    allowed_audiences = optional(list(string), [])
    allowed_scopes    = optional(list(string), [])
  })
  default = null
}

################################################################################
# Outbound Auth — OAuth2 Credential Providers
################################################################################

variable "oauth2_providers" {
  description = <<-EOT
    Map of OAuth2 credential providers to create. Each key is used as the for_each key.

    Supported vendors: GoogleOauth2, GithubOauth2, MicrosoftOauth2, SlackOauth2,
    CustomOauth2.

    Each value:
    - name: credential provider name (pattern: [a-zA-Z0-9\-_]+, max 128 chars)
    - vendor: one of the supported vendor strings listed above
    - client_id: OAuth2 client ID (max 256 chars)
    - client_secret: OAuth2 client secret (max 2048 chars)
    - discovery_url: OIDC discovery URL — required when vendor is CustomOauth2
  EOT
  type = map(object({
    name          = string
    vendor        = string
    client_id     = string
    client_secret = string
    discovery_url = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.oauth2_providers :
      contains([
        "GoogleOauth2", "GithubOauth2", "MicrosoftOauth2", "SlackOauth2", "CustomOauth2"
      ], v.vendor)
    ])
    error_message = "Each oauth2_providers entry must use a supported vendor: GoogleOauth2, GithubOauth2, MicrosoftOauth2, SlackOauth2, CustomOauth2."
  }

  validation {
    condition = alltrue([
      for k, v in var.oauth2_providers :
      v.vendor != "CustomOauth2" || v.discovery_url != null
    ])
    error_message = "discovery_url is required when vendor is CustomOauth2."
  }
}

################################################################################
# Outbound Auth — API Key Credential Providers
################################################################################

variable "api_key_providers" {
  description = <<-EOT
    Map of API key credential providers to create. Each key is used as the for_each key.
    The API key is stored securely in the AgentCore Token Vault (backed by Secrets Manager).

    Each value:
    - name: credential provider name (pattern: [a-zA-Z0-9\-_]+, max 128 chars)
    - api_key: the API key value to store
  EOT
  type = map(object({
    name    = string
    api_key = string
  }))
  default = {}
}

################################################################################
# Token Vault
################################################################################

variable "token_vault_kms_key_arn" {
  description = "ARN of the KMS key to use for customer-managed encryption of the account-level Token Vault. When null, AWS-managed encryption is used."
  type        = string
  default     = null
}

################################################################################
# Common
################################################################################

variable "tags" {
  description = "Key-value map of resource tags applied to all taggable resources in this module."
  type        = map(string)
  default     = {}
}
