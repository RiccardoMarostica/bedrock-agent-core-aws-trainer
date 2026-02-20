locals {
  s3_bucket_versioning = var.s3_enable_versioning ? "Enabled" : "Suspended"
}