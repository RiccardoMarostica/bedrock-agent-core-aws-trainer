variable "repository_name" {
  description = "Name of the ECR repository."
  type        = string
}

variable "image_tag_mutability" {
  description = "Tag mutability setting: MUTABLE or IMMUTABLE."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Whether images are scanned after being pushed."
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Allow deleting the repository even if it contains images."
  type        = bool
  default     = false
}

variable "lifecycle_policy_max_image_count" {
  description = "Maximum number of images to keep. Set to 0 to disable lifecycle policy."
  type        = number
  default     = 10
}

variable "lifecycle_policy_untagged_days" {
  description = "Expire untagged images after this many days. Set to 0 to disable."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Key-value map of resource tags."
  type        = map(string)
  default     = {}
}
