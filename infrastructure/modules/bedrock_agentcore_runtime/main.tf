################################################################################
# Bedrock AgentCore - Agent Runtime
################################################################################

resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = var.agent_runtime_name
  role_arn           = var.role_arn
  description        = var.description

  # --- Artifact (container or code) ---
  agent_runtime_artifact {
    dynamic "container_configuration" {
      for_each = var.container_uri != null ? [1] : []
      content {
        container_uri = var.container_uri
      }
    }

    dynamic "code_configuration" {
      for_each = var.code_configuration != null ? [var.code_configuration] : []
      content {
        entry_point = code_configuration.value.entry_points
        runtime     = code_configuration.value.runtime

        code {
          s3 {
            bucket     = code_configuration.value.s3_bucket
            prefix     = code_configuration.value.s3_prefix
            version_id = code_configuration.value.s3_version_id
          }
        }
      }
    }
  }

  # --- Network ---
  network_configuration {
    network_mode = var.network_mode

    dynamic "network_mode_config" {
      for_each = var.network_mode == "VPC" && var.vpc_config != null ? [var.vpc_config] : []
      content {
        subnets         = network_mode_config.value.subnet_ids
        security_groups = network_mode_config.value.security_group_ids
      }
    }
  }

  # --- Protocol ---
  dynamic "protocol_configuration" {
    for_each = var.protocol != null ? [var.protocol] : []
    content {
      server_protocol = protocol_configuration.value
    }
  }

  # --- Lifecycle ---
  dynamic "lifecycle_configuration" {
    for_each = var.lifecycle_configuration != null ? [var.lifecycle_configuration] : []
    content {
      idle_runtime_session_timeout = lifecycle_configuration.value.idle_timeout
      max_lifetime                 = lifecycle_configuration.value.max_lifetime
    }
  }

  # --- Authorizer ---
  dynamic "authorizer_configuration" {
    for_each = var.authorizer_configuration != null ? [var.authorizer_configuration] : []
    content {
      custom_jwt_authorizer {
        discovery_url    = authorizer_configuration.value.discovery_url
        allowed_audience = authorizer_configuration.value.allowed_audiences
        allowed_clients  = authorizer_configuration.value.allowed_clients
      }
    }
  }

  # --- Request Headers ---
  dynamic "request_header_configuration" {
    for_each = length(var.request_header_allowlist) > 0 ? [1] : []
    content {
      request_header_allowlist = var.request_header_allowlist
    }
  }

  # --- Environment Variables ---
  environment_variables = length(var.environment_variables) > 0 ? var.environment_variables : null

  tags = var.tags
}

################################################################################
# Bedrock AgentCore - Runtime Endpoint
################################################################################

resource "aws_bedrockagentcore_agent_runtime_endpoint" "this" {
  count = var.create_endpoint ? 1 : 0

  name                  = coalesce(var.endpoint_name, var.agent_runtime_name)
  agent_runtime_id      = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
  agent_runtime_version = var.endpoint_agent_runtime_version
  description           = var.endpoint_description

  tags = merge(var.tags, var.endpoint_tags)
}
