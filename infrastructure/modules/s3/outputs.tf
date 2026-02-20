output "bucket_name" {
  description = "The name of the S3 Bucket"
  value       = aws_s3_bucket.main.bucket
}

output "bucket_id" {
  description = "The ID of the S3 Bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "The ARN of the S3 Bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "The domain name of the S3 Bucket"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The regional domain name of the S3 Bucket"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].id : null
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].arn : null
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].domain_name : null
}

output "cloudfront_hosted_zone_id" {
  description = "The CloudFront Route 53 zone ID"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].hosted_zone_id : null
}
