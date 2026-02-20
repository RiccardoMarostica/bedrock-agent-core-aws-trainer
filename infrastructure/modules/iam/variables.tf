variable "project_name" {
  description = "A unique identifier for the project. It helps in distinguishing resources associated with this project from others"
  type        = string
}

variable "environment" {
  description = "Defines the deployment environment, such as 'staging' or 'production'"
  type        = string
}

variable "name" {
  description = "The name of the IAM Role"
  type        = string
}

variable "description" {
  description = "A description of the IAM Role"
  type        = string
  default     = "IAM Role for the resource"
}

variable "managed_policies" {
  description = "A list of managed policies by AWS that are used for this IAM Role"
  type        = list(string)
  default     = []
}

variable "custom_policies" {
  description = "A list of custom IAM policies to create and attach to the role"
  type = list(object({
    name        = string
    description = string
    policy      = string
  }))
  default = []
}

variable "assume_role_policy" {
  description = "The assume role JSON object to be used for this IAM Role"
  type        = string
}
