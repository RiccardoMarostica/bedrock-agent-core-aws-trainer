## Global variables
variable "aws_region" {
  description = "The AWS Region where resources will be created"
  type        = string
}

variable "environment" {
  description = "Defines the deployment environment (development, qa, prod)"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

## S3 variables
variable "s3_bucket_name" {
  description = "The name of the S3 bucket."
  type        = string
}

variable "s3_enable_versioning" {
  description = "Whether to enable versioning on the bucket."
  type        = bool
  default     = false
}

variable "s3_force_destroy" {
  description = "When true, allows Terraform to delete the bucket even if it contains objects."
  type        = bool
  default     = false
}

variable "s3_bucket_policy" {
  description = "Optional JSON bucket policy."
  type        = string
  default     = null
}

variable "s3_block_public_acls" {
  description = "Whether Amazon S3 should block public ACLs for this bucket."
  type        = bool
  default     = true
}

variable "s3_block_public_policy" {
  description = "Whether Amazon S3 should block public bucket policies for this bucket."
  type        = bool
  default     = true
}

variable "s3_ignore_public_acls" {
  description = "Whether Amazon S3 should ignore public ACLs for this bucket."
  type        = bool
  default     = true
}

variable "s3_restrict_public_buckets" {
  description = "Whether Amazon S3 should restrict public bucket policies for this bucket."
  type        = bool
  default     = true
}

## CloudFront variables
variable "enable_cloudfront" {
  description = "Whether to create a CloudFront distribution for the S3 bucket."
  type        = bool
  default     = false
}

variable "cloudfront_price_class" {
  description = "The price class for CloudFront distribution (PriceClass_All, PriceClass_200, PriceClass_100)."
  type        = string
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cloudfront_price_class)
    error_message = "Invalid price class. Allowed values are: 'PriceClass_All', 'PriceClass_200', 'PriceClass_100'."
  }
}

variable "cloudfront_default_root_object" {
  description = "The object that CloudFront returns when a viewer requests the root URL."
  type        = string
  default     = "index.html"
}

variable "cloudfront_allowed_methods" {
  description = "HTTP methods that CloudFront processes and forwards to S3."
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS"]
}

variable "cloudfront_cached_methods" {
  description = "HTTP methods for which CloudFront caches responses."
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "cloudfront_min_ttl" {
  description = "Minimum amount of time (in seconds) that objects stay in CloudFront cache."
  type        = number
  default     = 0
}

variable "cloudfront_default_ttl" {
  description = "Default amount of time (in seconds) that objects stay in CloudFront cache."
  type        = number
  default     = 3600
}

variable "cloudfront_max_ttl" {
  description = "Maximum amount of time (in seconds) that objects stay in CloudFront cache."
  type        = number
  default     = 86400
}

variable "cloudfront_viewer_protocol_policy" {
  description = "Protocol policy for viewers (allow-all, https-only, redirect-to-https)."
  type        = string
  default     = "redirect-to-https"
}

variable "cloudfront_compress" {
  description = "Whether CloudFront automatically compresses content."
  type        = bool
  default     = true
}

variable "cloudfront_custom_error_responses" {
  description = "Custom error response configuration for CloudFront."
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = []
}