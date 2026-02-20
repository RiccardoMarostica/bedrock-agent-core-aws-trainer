################################################################################
# Required Variables
################################################################################

variable "user_pool_name" {
  description = "Name of the Cognito User Pool."
  type        = string
}

variable "resource_server_identifier" {
  description = "Unique identifier for the resource server (used as scope prefix)."
  type        = string
}

variable "resource_server_name" {
  description = "Display name for the resource server."
  type        = string
}

variable "client_name" {
  description = "Name of the M2M app client."
  type        = string
}

################################################################################
# Optional Variables
################################################################################

variable "scopes" {
  description = "List of scope names to create on the resource server (e.g. [\"invoke\"])."
  type        = list(string)
  default     = ["invoke"]
}

variable "tags" {
  description = "Key-value map of resource tags."
  type        = map(string)
  default     = {}
}
