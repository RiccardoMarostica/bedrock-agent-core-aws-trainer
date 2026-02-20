# S3 Module

This Terraform module creates and configures Amazon S3 buckets with security best practices, versioning support, and customizable access controls.

## Features

- **Security by Default**: Public access blocked, bucket ownership enforced
- **CloudFront Integration**: Optional CloudFront distribution with Origin Access Control (OAC)
- **Versioning Support**: Optional object versioning
- **Custom Bucket Policies**: Template-based policy support
- **Encryption**: Server-side encryption enabled by default
- **Access Controls**: Configurable public access block settings
- **Force Destroy**: Optional bucket deletion with objects

## Architecture

The module creates:
1. S3 bucket with specified configuration
2. Bucket versioning configuration
3. Bucket ownership controls (ACLs disabled)
4. Public access block settings
5. Optional custom bucket policy

## Usage

### Basic Example

```hcl
module "my_bucket" {
  source = "../../modules/s3"

  aws_region   = "eu-west-1"
  environment  = "dev"
  project_name = "my-project"

  s3_bucket_name       = "my-app-data"
  s3_enable_versioning = true
}
```

### With Custom Policy

```hcl
module "my_bucket" {
  source = "../../modules/s3"

  aws_region   = "eu-west-1"
  environment  = "dev"
  project_name = "my-project"

  s3_bucket_name = "my-app-data"
  
  s3_bucket_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowLambdaAccess"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:role/lambda-role"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::my-app-data/*"
      }
    ]
  })
}
```

### Development Bucket (Force Destroy)

```hcl
module "dev_bucket" {
  source = "../../modules/s3"

  aws_region   = "eu-west-1"
  environment  = "dev"
  project_name = "my-project"

  s3_bucket_name  = "my-app-dev-data"
  s3_force_destroy = true  # Allows Terraform to delete bucket with objects
}
```

### Public Access Configuration

```hcl
module "public_bucket" {
  source = "../../modules/s3"

  aws_region   = "eu-west-1"
  environment  = "dev"
  project_name = "my-project"

  s3_bucket_name = "my-public-assets"

  # Allow public access (use with caution!)
  s3_block_public_acls       = false
  s3_block_public_policy     = false
  s3_ignore_public_acls      = false
  s3_restrict_public_buckets = false
}
```

### With CloudFront Distribution

```hcl
module "cdn_bucket" {
  source = "../../modules/s3"

  aws_region   = "eu-west-1"
  environment  = "prod"
  project_name = "my-project"

  s3_bucket_name       = "my-app-static-assets"
  s3_enable_versioning = true

  # Enable CloudFront
  enable_cloudfront                = true
  cloudfront_price_class           = "PriceClass_100"
  cloudfront_default_root_object   = "index.html"
  cloudfront_viewer_protocol_policy = "redirect-to-https"
  
  # Custom error responses for SPA
  cloudfront_custom_error_responses = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    }
  ]
}
```

### Complete Example (Example bucket)

```hcl
module "s3_example_bucket" {
  source = "../../modules/s3"

  aws_region   = "eu-west-1"
  environment  = "dev"
  project_name = "example-project"

  s3_bucket_name       = "example-bucket-dev"
  s3_enable_versioning = true
}
```

## Inputs

### Required Variables

| Name | Type | Description |
|------|------|-------------|
| `aws_region` | string | AWS region for resource creation |
| `environment` | string | Environment name (dev, prod, etc.) |
| `project_name` | string | Project identifier |
| `s3_bucket_name` | string | Name of the S3 bucket (must be globally unique) |

### Optional Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `s3_enable_versioning` | bool | `false` | Enable object versioning |
| `s3_force_destroy` | bool | `false` | Allow Terraform to delete bucket with objects |
| `s3_bucket_policy` | string | `null` | Custom bucket policy JSON |
| `s3_block_public_acls` | bool | `true` | Block public ACLs |
| `s3_block_public_policy` | bool | `true` | Block public bucket policies |
| `s3_ignore_public_acls` | bool | `true` | Ignore public ACLs |
| `s3_restrict_public_buckets` | bool | `true` | Restrict public bucket policies |
| `enable_cloudfront` | bool | `false` | Create CloudFront distribution |
| `cloudfront_price_class` | string | `"PriceClass_100"` | CloudFront price class |
| `cloudfront_default_root_object` | string | `"index.html"` | Default root object |
| `cloudfront_allowed_methods` | list(string) | `["GET", "HEAD", "OPTIONS"]` | Allowed HTTP methods |
| `cloudfront_cached_methods` | list(string) | `["GET", "HEAD"]` | Cached HTTP methods |
| `cloudfront_min_ttl` | number | `0` | Minimum TTL in seconds |
| `cloudfront_default_ttl` | number | `3600` | Default TTL in seconds |
| `cloudfront_max_ttl` | number | `86400` | Maximum TTL in seconds |
| `cloudfront_viewer_protocol_policy` | string | `"redirect-to-https"` | Viewer protocol policy |
| `cloudfront_compress` | bool | `true` | Enable compression |
| `cloudfront_custom_error_responses` | list(object) | `[]` | Custom error responses |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | The name of the S3 bucket |
| `bucket_id` | The ID of the S3 bucket |
| `bucket_arn` | The ARN of the S3 bucket |
| `bucket_domain_name` | The domain name of the S3 bucket |
| `bucket_regional_domain_name` | The regional domain name of the S3 bucket |
| `cloudfront_distribution_id` | The ID of the CloudFront distribution (if enabled) |
| `cloudfront_distribution_arn` | The ARN of the CloudFront distribution (if enabled) |
| `cloudfront_domain_name` | The domain name of the CloudFront distribution (if enabled) |
| `cloudfront_hosted_zone_id` | The CloudFront Route 53 zone ID (if enabled) |

## Bucket Naming

S3 bucket names must be:
- Globally unique across all AWS accounts
- 3-63 characters long
- Lowercase letters, numbers, hyphens only
- Start and end with letter or number
- Not formatted as IP address

### Naming Convention

```
${project_name}-${purpose}-${environment}
```

Examples:
- `myapp-logs-staging`

## Versioning

When versioning is enabled:
- Every object modification creates a new version
- Previous versions are retained
- Protects against accidental deletion
- Enables rollback to previous versions

### Versioning Use Cases

- **Backup and Recovery**: Restore previous versions
- **Compliance**: Maintain audit trail
- **Accidental Deletion Protection**: Recover deleted objects

### Versioning Costs

- Storage costs for all versions
- Consider lifecycle policies to delete old versions

## Public Access Block

The module blocks public access by default for security:

| Setting | Default | Description |
|---------|---------|-------------|
| `block_public_acls` | `true` | Blocks new public ACLs |
| `block_public_policy` | `true` | Blocks new public bucket policies |
| `ignore_public_acls` | `true` | Ignores existing public ACLs |
| `restrict_public_buckets` | `true` | Restricts public bucket policies |

### When to Allow Public Access

Only disable these settings if you need:
- Public website hosting
- Public asset distribution
- Public data sharing

**Always use CloudFront for public content distribution instead of direct S3 access.**

## Bucket Policies

### Lambda Access Policy

```hcl
s3_bucket_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Sid    = "AllowLambdaReadWrite"
      Effect = "Allow"
      Principal = {
        AWS = module.lambda_function.lambda_role_arn
      }
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      Resource = "${module.s3_bucket.bucket_arn}/*"
    }
  ]
})
```

### Cross-Account Access

```hcl
s3_bucket_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Sid    = "AllowCrossAccountAccess"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::987654321098:root"
      }
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        "${module.s3_bucket.bucket_arn}",
        "${module.s3_bucket.bucket_arn}/*"
      ]
    }
  ]
})
```

### CloudFront Access (Automatic with enable_cloudfront)

When `enable_cloudfront = true`, the module automatically creates:
- CloudFront Origin Access Control (OAC)
- CloudFront distribution
- S3 bucket policy allowing CloudFront access

The bucket remains private and is only accessible through CloudFront.

## IAM Permissions

### Read Permissions

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:ListBucket"
  ],
  "Resource": [
    "${bucket_arn}",
    "${bucket_arn}/*"
  ]
}
```

### Write Permissions

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:PutObject",
    "s3:PutObjectAcl",
    "s3:DeleteObject"
  ],
  "Resource": "${bucket_arn}/*"
}
```

### Full Access

```json
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": [
    "${bucket_arn}",
    "${bucket_arn}/*"
  ]
}
```

## CloudFront Distribution

### Overview

When `enable_cloudfront = true`, the module creates:
1. **CloudFront Origin Access Control (OAC)**: Modern, secure way to access S3
2. **CloudFront Distribution**: CDN for global content delivery
3. **S3 Bucket Policy**: Automatically configured to allow only CloudFront access

### Benefits

- **Security**: S3 bucket remains private, accessible only through CloudFront
- **Performance**: Content cached at edge locations worldwide
- **Cost Optimization**: Reduced S3 data transfer costs
- **HTTPS**: Automatic HTTPS support with CloudFront certificate

### Price Classes

| Price Class | Coverage | Use Case |
|-------------|----------|----------|
| `PriceClass_100` | US, Canada, Europe | Most cost-effective |
| `PriceClass_200` | Above + Asia, Africa, Middle East | Balanced |
| `PriceClass_All` | All edge locations | Best performance |

### Cache Behavior

Configure TTL (Time To Live) values based on content type:

| Content Type | Min TTL | Default TTL | Max TTL |
|--------------|---------|-------------|---------|
| Static assets (images, CSS, JS) | 0 | 86400 (1 day) | 31536000 (1 year) |
| HTML pages | 0 | 3600 (1 hour) | 86400 (1 day) |
| API responses | 0 | 0 | 3600 (1 hour) |

### Custom Error Responses

Useful for Single Page Applications (SPAs):

```hcl
cloudfront_custom_error_responses = [
  {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  },
  {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }
]
```

### Accessing Content

After deployment, access your content via CloudFront domain:
```
https://<distribution-id>.cloudfront.net/path/to/file
```

Get the domain from outputs:
```hcl
output "cdn_url" {
  value = module.my_bucket.cloudfront_domain_name
}
```

## Encryption

S3 buckets use server-side encryption by default:
- **SSE-S3**: Amazon S3-managed keys (default)
- **SSE-KMS**: AWS KMS-managed keys (optional)
- **SSE-C**: Customer-provided keys (optional)

The module uses SSE-S3 by default (no additional configuration needed).

## Force Destroy

The `s3_force_destroy` option allows Terraform to delete buckets containing objects:

```hcl
s3_force_destroy = true  # Use only for dev/test environments
```

**Warning**: This permanently deletes all objects in the bucket!

### When to Use

- Development environments
- Test buckets
- Temporary storage

### When NOT to Use

- Production environments
- Buckets with important data
- Compliance-regulated data

## Best Practices

### 1. Enable Versioning for Important Data

```hcl
s3_enable_versioning = true
```

### 2. Use Lifecycle Policies

Add lifecycle rules to:
- Transition old versions to cheaper storage classes
- Delete old versions after retention period
- Clean up incomplete multipart uploads

### 3. Enable Access Logging

Track bucket access for security and compliance:

```hcl
resource "aws_s3_bucket_logging" "example" {
  bucket = module.s3_bucket.bucket_id

  target_bucket = module.log_bucket.bucket_id
  target_prefix = "s3-access-logs/"
}
```

### 4. Use Bucket Policies for Access Control

Prefer bucket policies over ACLs for access control.

### 5. Enable Encryption

Always use encryption for sensitive data (enabled by default).

### 6. Monitor Bucket Size and Costs

Use CloudWatch metrics and AWS Cost Explorer to monitor:
- Storage size
- Request counts
- Data transfer costs

## Troubleshooting

### Bucket Name Already Exists

**Issue**: `BucketAlreadyExists` error

**Solutions**:
- Choose a different bucket name (must be globally unique)
- Check if bucket exists in another region
- Verify bucket wasn't recently deleted (may take time to free name)

### Access Denied Errors

**Issue**: `AccessDenied` when accessing objects

**Solutions**:
- Check IAM permissions
- Verify bucket policy allows access
- Ensure public access block settings are appropriate
- Check object ACLs

### Versioning Cannot Be Disabled

**Issue**: Cannot disable versioning once enabled

**Solution**:
- Versioning can only be suspended, not disabled
- Use lifecycle policies to delete old versions

### Force Destroy Not Working

**Issue**: Terraform cannot delete bucket with objects

**Solutions**:
- Set `s3_force_destroy = true`
- Manually empty bucket before destroying
- Use AWS CLI: `aws s3 rm s3://bucket-name --recursive`

## Cost Optimization

### Storage Classes

Consider using different storage classes:
- **S3 Standard**: Frequently accessed data
- **S3 Intelligent-Tiering**: Automatic cost optimization
- **S3 Standard-IA**: Infrequently accessed data
- **S3 Glacier**: Archive storage

### Lifecycle Policies

Automatically transition or delete objects:

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "example" {
  bucket = module.s3_bucket.bucket_id

  rule {
    id     = "archive-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
```

## Examples

### Temporary Processing Bucket

```hcl
module "temp_bucket" {
  source = "../../modules/s3"

  aws_region   = "eu-west-1"
  environment  = "dev"
  project_name = "example-project"

  s3_bucket_name       = "example-project-temp-dev"
  s3_enable_versioning = false
  s3_force_destroy     = true
}
```

## References

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Terraform AWS Provider - S3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)
- [S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
