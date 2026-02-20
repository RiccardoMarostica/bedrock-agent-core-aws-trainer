# IAM Module

This Terraform module creates and configures AWS IAM roles with support for both AWS managed policies and custom IAM policies.

## Features

- **IAM Role Creation**: Create IAM roles with custom assume role policies
- **AWS Managed Policies**: Attach multiple AWS managed policies to the role
- **Custom IAM Policies**: Create and attach multiple custom IAM policies
- **Tagging Support**: Automatic tagging with project, environment, and name
- **Flexible Configuration**: Support for various IAM use cases

## Architecture

The module creates:
1. IAM role with specified assume role policy
2. Attachments for AWS managed policies (optional)
3. Custom IAM policies (optional)
4. Attachments for custom policies to the role

## Usage

### Basic Example with Managed Policies

```hcl
module "lambda_role" {
  source = "../../modules/iam"

  project_name = "my-project"
  environment  = "dev"
  name         = "lambda-execution-role"
  description  = "IAM role for Lambda function execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  managed_policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}
```

### With Custom Policies

```hcl
module "s3_access_role" {
  source = "../../modules/iam"

  project_name = "my-project"
  environment  = "prod"
  name         = "s3-access-role"
  description  = "IAM role with custom S3 access policies"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  custom_policies = [
    {
      name        = "s3-read-access"
      description = "Allow read access to specific S3 buckets"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:ListBucket"
            ]
            Resource = [
              "arn:aws:s3:::my-bucket",
              "arn:aws:s3:::my-bucket/*"
            ]
          }
        ]
      })
    },
    {
      name        = "s3-write-access"
      description = "Allow write access to specific S3 buckets"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:PutObject",
              "s3:DeleteObject"
            ]
            Resource = "arn:aws:s3:::my-bucket/*"
          }
        ]
      })
    }
  ]
}
```

### Combined: Managed and Custom Policies

```hcl
module "glue_role" {
  source = "../../modules/iam"

  project_name = "data-pipeline"
  environment  = "prod"
  name         = "glue-etl-role"
  description  = "IAM role for AWS Glue ETL jobs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  # AWS managed policies
  managed_policies = [
    "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  ]

  # Custom policies
  custom_policies = [
    {
      name        = "glue-s3-access"
      description = "Custom S3 access for Glue jobs"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject"
            ]
            Resource = [
              "arn:aws:s3:::data-lake-raw/*",
              "arn:aws:s3:::data-lake-processed/*"
            ]
          }
        ]
      })
    }
  ]
}
```

### Lambda Function Role

```hcl
module "lambda_role" {
  source = "../../modules/iam"

  project_name = "serverless-app"
  environment  = "prod"
  name         = "lambda-api-role"
  description  = "IAM role for API Lambda functions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  managed_policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  ]

  custom_policies = [
    {
      name        = "dynamodb-access"
      description = "Access to DynamoDB tables"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "dynamodb:GetItem",
              "dynamodb:PutItem",
              "dynamodb:UpdateItem",
              "dynamodb:Query"
            ]
            Resource = "arn:aws:dynamodb:*:*:table/my-table"
          }
        ]
      })
    }
  ]
}
```

## Inputs

### Required Variables

| Name | Type | Description |
|------|------|-------------|
| `project_name` | string | Project identifier for tagging |
| `environment` | string | Environment name (dev, prod, etc.) |
| `name` | string | Name of the IAM role |
| `assume_role_policy` | string | JSON policy document for assume role |

### Optional Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `description` | string | `"The IAM Role for the resource"` | Description of the IAM role |
| `managed_policies` | list(string) | `[]` | List of AWS managed policy ARNs to attach |
| `custom_policies` | list(object) | `[]` | List of custom policies to create and attach |

### Custom Policies Object Structure

```hcl
custom_policies = [
  {
    name        = string  # Name of the policy
    description = string  # Description of the policy
    policy      = string  # JSON policy document
  }
]
```

## Outputs

| Name | Description |
|------|-------------|
| `arn` | The ARN of the IAM role |
| `id` | The ID of the IAM role |
| `name` | The name of the IAM role |
| `custom_policy_arns` | List of ARNs for custom policies created |
| `custom_policy_ids` | List of IDs for custom policies created |

## Common Use Cases

### 1. Lambda Execution Role

```hcl
assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Action = "sts:AssumeRole"
    Effect = "Allow"
    Principal = {
      Service = "lambda.amazonaws.com"
    }
  }]
})
```

### 2. EC2 Instance Role

```hcl
assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Action = "sts:AssumeRole"
    Effect = "Allow"
    Principal = {
      Service = "ec2.amazonaws.com"
    }
  }]
})
```

### 3. Cross-Account Access Role

```hcl
assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Action = "sts:AssumeRole"
    Effect = "Allow"
    Principal = {
      AWS = "arn:aws:iam::123456789012:root"
    }
    Condition = {
      StringEquals = {
        "sts:ExternalId" = "unique-external-id"
      }
    }
  }]
})
```

### 4. ECS Task Execution Role

```hcl
assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Action = "sts:AssumeRole"
    Effect = "Allow"
    Principal = {
      Service = "ecs-tasks.amazonaws.com"
    }
  }]
})
```

## AWS Managed Policies

Common AWS managed policies you can use:

### Lambda
- `arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole`
- `arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole`
- `arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess`

### Glue
- `arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole`
- `arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess`

### EC2
- `arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess`
- `arn:aws:iam::aws:policy/AmazonEC2FullAccess`

### S3
- `arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess`
- `arn:aws:iam::aws:policy/AmazonS3FullAccess`

### ECS
- `arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`

## Custom Policy Examples

### S3 Bucket Access

```hcl
{
  name        = "s3-bucket-access"
  description = "Access to specific S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::my-bucket",
          "arn:aws:s3:::my-bucket/*"
        ]
      }
    ]
  })
}
```

### DynamoDB Table Access

```hcl
{
  name        = "dynamodb-table-access"
  description = "Read/write access to DynamoDB table"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/my-table"
      }
    ]
  })
}
```

### Secrets Manager Access

```hcl
{
  name        = "secrets-manager-access"
  description = "Access to specific secrets"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:my-secret-*"
      }
    ]
  })
}
```

### CloudWatch Logs

```hcl
{
  name        = "cloudwatch-logs-access"
  description = "Write logs to CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/*"
      }
    ]
  })
}
```

### SQS Queue Access

```hcl
{
  name        = "sqs-queue-access"
  description = "Send and receive messages from SQS"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "arn:aws:sqs:*:*:my-queue"
      }
    ]
  })
}
```

## Best Practices

### 1. Principle of Least Privilege

Grant only the permissions required for the task:

```hcl
# Good: Specific permissions
Action = [
  "s3:GetObject",
  "s3:PutObject"
]

# Avoid: Overly broad permissions
Action = "s3:*"
```

### 2. Use Resource-Level Permissions

Restrict access to specific resources:

```hcl
Resource = [
  "arn:aws:s3:::my-specific-bucket/*"
]

# Avoid wildcards when possible
# Resource = "arn:aws:s3:::*"
```

### 3. Separate Policies by Function

Create separate custom policies for different access patterns:

```hcl
custom_policies = [
  {
    name   = "read-access"
    policy = "..." # Read-only permissions
  },
  {
    name   = "write-access"
    policy = "..." # Write permissions
  }
]
```

### 4. Use Conditions for Enhanced Security

Add conditions to policies when appropriate:

```hcl
policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Effect = "Allow"
    Action = "s3:GetObject"
    Resource = "arn:aws:s3:::my-bucket/*"
    Condition = {
      IpAddress = {
        "aws:SourceIp" = "203.0.113.0/24"
      }
    }
  }]
})
```

### 5. Tag Your Resources

The module automatically tags resources with project, environment, and name for better organization and cost tracking.

## Troubleshooting

### Policy Validation Errors

**Issue**: Invalid JSON in policy document

**Solutions**:
- Use `jsonencode()` to ensure valid JSON
- Validate JSON syntax before applying
- Check for missing commas or brackets

### Permission Denied Errors

**Issue**: Role doesn't have required permissions

**Solutions**:
- Verify the policy includes necessary actions
- Check resource ARNs are correct
- Ensure assume role policy allows the service to assume the role

### Policy Size Limits

**Issue**: Policy exceeds size limits

**Solutions**:
- AWS managed policy: 6,144 characters
- Inline policy: 2,048 characters per policy, 10,240 total
- Split large policies into multiple custom policies
- Use AWS managed policies where possible

### Role Already Exists

**Issue**: Role name conflicts with existing role

**Solutions**:
- Choose a unique role name
- Check if role exists in the account
- Use naming conventions to avoid conflicts

## Security Considerations

### 1. Avoid Wildcard Permissions

```hcl
# Avoid
Action = "*"
Resource = "*"

# Prefer
Action = ["s3:GetObject", "s3:PutObject"]
Resource = "arn:aws:s3:::specific-bucket/*"
```

### 2. Use External ID for Cross-Account Access

```hcl
Condition = {
  StringEquals = {
    "sts:ExternalId" = "unique-external-id"
  }
}
```

### 3. Enable MFA for Sensitive Operations

```hcl
Condition = {
  Bool = {
    "aws:MultiFactorAuthPresent" = "true"
  }
}
```

### 4. Restrict by IP Address

```hcl
Condition = {
  IpAddress = {
    "aws:SourceIp" = ["203.0.113.0/24"]
  }
}
```

## Examples

### Data Pipeline Role

```hcl
module "data_pipeline_role" {
  source = "../../modules/iam"

  project_name = "data-platform"
  environment  = "prod"
  name         = "data-pipeline-role"
  description  = "Role for data pipeline processing"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })

  managed_policies = [
    "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  ]

  custom_policies = [
    {
      name        = "s3-data-access"
      description = "Access to data lake buckets"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = [
            "arn:aws:s3:::data-lake-raw/*",
            "arn:aws:s3:::data-lake-processed/*"
          ]
        }]
      })
    }
  ]
}
```

## References

- [AWS IAM Documentation](https://docs.aws.amazon.com/iam/)
- [Terraform AWS Provider - IAM](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [IAM Policy Reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies.html)
