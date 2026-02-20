# IAM Policies

This folder contains JSON IAM policies used by Terraform modules to configure permissions for AWS resources.

## Structure

```
iam/
├── README.md                          # This guide
├── policies/                          # IAM Policies (role permissions)
│   ├── agentcore_ecr.json             # ECR policy for AgentCore Runtime
│   ├── agentcore_s3.json              # S3 policy for AgentCore Runtime
│   ├── agentcore_logs.json            # CloudWatch Logs policy for AgentCore Runtime
│   ├── agentcore_bedrock.json         # Bedrock policy for AgentCore Runtime
│   ├── agentcore_memory_dataplane.json # Memory dataplane policy
│   ├── agentcore_workload_identity.json # Workload identity policy
│   ├── agentcore_gateway.json         # Gateway policy
│   ├── agentcore_gateway_oauth.json   # Gateway OAuth2 policy
│   └── agentcore_invoke_gateway.json  # Invoke gateway policy
├── trust_policies/                    # Trust Policies (who can assume the role)
│   └── agentcore_runtime.json         # Trust policy for Bedrock AgentCore
└── permissions/                       # Resource Permissions
```

## Policy Types

### Policies (`policies/`)

Define permissions (what the role can do). Created as IAM Policies and attached to the role.

### Trust Policies (`trust_policies/`)

Define who can assume the role (which AWS service or account). Used as `assume_role_policy` on the IAM role.

### Permissions (`permissions/`)

Define permissions for specific resources (e.g., data sources, dashboards). Loaded with `jsondecode(file(...))` and passed to modules.

---

## Existing Policies

### AgentCore Runtime

IAM role for Amazon Bedrock AgentCore Runtime, the serverless service for deploying AI agents.

#### `trust_policies/agentcore_runtime.json`

Trust policy allowing the Bedrock AgentCore service to assume the role.

| Principal | Action |
|-----------|--------|
| `bedrock-agentcore.amazonaws.com` | `sts:AssumeRole` |

#### `policies/agentcore_ecr.json`

Allows the runtime to pull container images from Amazon ECR.

| Sid | Service | Actions | Resources |
|-----|---------|---------|-----------|
| `AllowECRAuthToken` | ECR | `GetAuthorizationToken` | `*` |
| `AllowECRPullImages` | ECR | `BatchGetImage`, `GetDownloadUrlForLayer` | All ECR repositories in the account |

**Template variables:**

| Variable | Description |
|----------|-------------|
| `${aws_region}` | AWS region |
| `${aws_account_id}` | AWS account ID |

#### `policies/agentcore_s3.json`

Allows the runtime to read code artifacts from the S3 bucket.

| Sid | Service | Actions | Resources |
|-----|---------|---------|-----------|
| `AllowS3GetCodeArtifacts` | S3 | `GetObject`, `GetObjectVersion` | Objects in the code bucket |
| `AllowS3ListCodeBucket` | S3 | `ListBucket` | Code bucket |

**Template variables:**

| Variable | Description |
|----------|-------------|
| `${agent_code_bucket_arn}` | ARN of the S3 bucket for code artifacts |

#### `policies/agentcore_logs.json`

Allows the runtime to write logs to CloudWatch.

| Sid | Service | Actions | Resources |
|-----|---------|---------|-----------|
| `AllowCloudWatchLogs` | CloudWatch Logs | `CreateLogGroup`, `CreateLogStream`, `PutLogEvents` | All log groups in the account |

**Template variables:**

| Variable | Description |
|----------|-------------|
| `${aws_region}` | AWS region |
| `${aws_account_id}` | AWS account ID |

#### `policies/agentcore_bedrock.json`

Allows the runtime to invoke Amazon Bedrock foundation models.

| Sid | Service | Actions | Resources |
|-----|---------|---------|-----------|
| `AllowBedrockModelInvocation` | Bedrock | `InvokeModel`, `InvokeModelWithResponseStream` | All foundation models |

**Template variables:**

| Variable | Description |
|----------|-------------|
| `${aws_region}` | AWS region |

---

## Usage in Terraform

Policies are loaded via `templatefile()`:

```hcl
module "agentcore_runtime_role" {
  source = "../../modules/iam"

  name        = "agentcore-runtime"
  description = "IAM role assumed by Bedrock AgentCore Runtime"

  assume_role_policy = templatefile("../../../iam/trust_policies/agentcore_runtime.json", {})

  custom_policies = [
    {
      name        = "agentcore-ecr"
      description = "Allow AgentCore to pull container images from ECR"
      policy = templatefile("../../../iam/policies/agentcore_ecr.json", {
        aws_region     = local.region
        aws_account_id = local.account_id
      })
    }
  ]
}
```

---

## Creating New Policies

### 1. Policy file (`policies/service_name.json`)

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PermissionDescription",
            "Effect": "Allow",
            "Action": [
                "service:Action1",
                "service:Action2"
            ],
            "Resource": [
                "${variable_arn}"
            ]
        }
    ]
}
```

### 2. Trust policy (`trust_policies/service_name.json`)

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "service-name.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

### Common Principals for Trust Policies

| Service | Principal |
|---------|-----------|
| Bedrock AgentCore | `bedrock-agentcore.amazonaws.com` |
| Lambda | `lambda.amazonaws.com` |
| Glue | `glue.amazonaws.com` |
| EC2 | `ec2.amazonaws.com` |
| ECS Tasks | `ecs-tasks.amazonaws.com` |
| Step Functions | `states.amazonaws.com` |
| EventBridge | `events.amazonaws.com` |
| API Gateway | `apigateway.amazonaws.com` |

---

## Best Practices

### Least Privilege Principle

Grant only the permissions strictly necessary:

```json
// Good: specific permissions
"Action": ["s3:GetObject", "s3:PutObject"]

// Avoid: overly broad permissions
"Action": "s3:*"
```

### Specific Resources

Limit resources when possible:

```json
// Good: specific resources
"Resource": ["arn:aws:s3:::my-bucket/*"]

// Avoid: all resources
"Resource": "*"
```

### Use Descriptive Sids

```json
{
    "Sid": "AllowS3ReadAccessToDataLake",
    "Effect": "Allow",
    ...
}
```

### Template Variables

Use variables to make policies reusable:

```json
"Resource": [
    "arn:aws:s3:::${bucket_name}/*",
    "arn:aws:logs:${region}:${account_id}:log-group:/aws-glue/*"
]
```

---

## Validation

### AWS CLI

```bash
aws iam create-policy \
    --policy-name test-policy \
    --policy-document file://iam/policies/agentcore_ecr.json \
    --dry-run
```

### IAM Policy Simulator

Use [IAM Policy Simulator](https://policysim.aws.amazon.com/) to test permissions.

---

## References

- [IAM Policy Reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies.html)
- [IAM Actions Reference](https://docs.aws.amazon.com/service-authorization/latest/reference/reference_policies_actions-resources-contextkeys.html)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
