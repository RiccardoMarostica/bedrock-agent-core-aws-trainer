#####
# ----- S3 BUCKET -----
# This section is for the S3 bucket configuration.
# This creates an S3 Bucket with configuration options.
#####
resource "aws_s3_bucket" "main" {
  bucket        = var.s3_bucket_name
  force_destroy = var.s3_force_destroy

  tags = {
    "Name" = var.s3_bucket_name
  }
}


# Enable or disable versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = local.s3_bucket_versioning
  }
}

# Optional bucket policy (custom or CloudFront)
resource "aws_s3_bucket_policy" "main" {
  count = var.s3_bucket_policy != null || var.enable_cloudfront ? 1 : 0

  bucket = aws_s3_bucket.main.id
  policy = var.enable_cloudfront ? data.aws_iam_policy_document.cloudfront_oac[0].json : var.s3_bucket_policy
}

#####
# ----- S3 BUCKET ACCESS BLOCK -----
# This section is for the S3 bucket access block configuration.
# This creates an S3 Bucket Access Block with configuration options.
#####

# Bucket ownership controls (replaces ACLs)
resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Public access block configuration
resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = var.s3_block_public_acls
  block_public_policy     = var.s3_block_public_policy
  ignore_public_acls      = var.s3_ignore_public_acls
  restrict_public_buckets = var.s3_restrict_public_buckets
}

#####
# ----- CLOUDFRONT DISTRIBUTION -----
# This section creates a CloudFront distribution with Origin Access Control (OAC)
# to securely access the private S3 bucket.
#####

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "main" {
  count = var.enable_cloudfront ? 1 : 0

  name                              = "${var.s3_bucket_name}-oac"
  description                       = "OAC for ${var.s3_bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  count = var.enable_cloudfront ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.s3_bucket_name}"
  default_root_object = var.cloudfront_default_root_object
  price_class         = var.cloudfront_price_class

  origin {
    domain_name              = aws_s3_bucket.main.bucket_regional_domain_name
    origin_id                = "S3-${var.s3_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.main[0].id
  }

  default_cache_behavior {
    allowed_methods  = var.cloudfront_allowed_methods
    cached_methods   = var.cloudfront_cached_methods
    target_origin_id = "S3-${var.s3_bucket_name}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = var.cloudfront_viewer_protocol_policy
    min_ttl                = var.cloudfront_min_ttl
    default_ttl            = var.cloudfront_default_ttl
    max_ttl                = var.cloudfront_max_ttl
    compress               = var.cloudfront_compress
  }

  # Custom error responses
  dynamic "custom_error_response" {
    for_each = var.cloudfront_custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.s3_bucket_name}-cloudfront"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Policy Document for CloudFront OAC to access S3
data "aws_iam_policy_document" "cloudfront_oac" {
  count = var.enable_cloudfront ? 1 : 0

  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.main.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main[0].arn]
    }
  }
}
