################################################################################
# Required Variables
################################################################################

variable "name" {
  description = "Name of the AgentCore Memory. Must match pattern: [0-9a-zA-Z][-]? repeated up to 100 times."
  type        = string

  validation {
    condition     = can(regex("^([0-9a-zA-Z][-]?){1,100}$", var.name))
    error_message = "name must match pattern ^([0-9a-zA-Z][-]?){1,100}$."
  }
}

variable "event_expiry_duration" {
  description = "Number of days after which memory events expire. Must be between 7 and 365."
  type        = number
  default     = 30

  validation {
    condition     = var.event_expiry_duration >= 7 && var.event_expiry_duration <= 365
    error_message = "event_expiry_duration must be between 7 and 365 days."
  }
}

################################################################################
# Optional Variables
################################################################################

variable "description" {
  description = "Description of the memory."
  type        = string
  default     = null
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key used to encrypt the memory. If null, AWS-managed encryption is used."
  type        = string
  default     = null
}

variable "memory_execution_role_arn" {
  description = "ARN of the IAM role that the memory service assumes. Required when using custom memory strategies with model processing."
  type        = string
  default     = null
}

variable "tags" {
  description = "Key-value map of resource tags."
  type        = map(string)
  default     = {}
}

################################################################################
# Memory Strategy Variables
################################################################################

variable "strategies" {
  description = <<-EOT
    Map of memory strategies to create. Each key is used as the for_each key.
    Only one strategy of each built-in type can exist per memory (enforced by AWS).

    Each value:
    - name: strategy name
    - type: SEMANTIC | SUMMARIZATION | USER_PREFERENCE
    - namespaces: set of namespace identifiers where this strategy applies
    - description: optional description
  EOT
  type = map(object({
    name        = string
    type        = string
    namespaces  = set(string)
    description = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.strategies :
      contains(["SEMANTIC", "SUMMARIZATION", "USER_PREFERENCE"], v.type)
    ])
    error_message = "Each strategy type must be one of: SEMANTIC, SUMMARIZATION, USER_PREFERENCE."
  }
}
