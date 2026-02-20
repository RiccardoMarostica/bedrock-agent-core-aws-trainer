################################################################################
# Bedrock AgentCore — Gateway
################################################################################

resource "aws_bedrockagentcore_gateway" "this" {
  name            = var.name
  role_arn        = var.role_arn
  authorizer_type = var.authorizer_type
  protocol_type   = var.protocol_type
  description     = var.description
  exception_level = var.exception_level
  kms_key_arn     = var.kms_key_arn

  # --- Authorizer (CUSTOM_JWT only) ---
  dynamic "authorizer_configuration" {
    for_each = var.authorizer_type == "CUSTOM_JWT" && var.authorizer_configuration != null ? [var.authorizer_configuration] : []
    content {
      custom_jwt_authorizer {
        discovery_url    = authorizer_configuration.value.discovery_url
        allowed_audience = authorizer_configuration.value.allowed_audiences
        allowed_clients  = authorizer_configuration.value.allowed_clients
      }
    }
  }

  # --- Protocol (MCP) ---
  dynamic "protocol_configuration" {
    for_each = var.protocol_configuration != null ? [var.protocol_configuration] : []
    content {
      mcp {
        instructions       = protocol_configuration.value.instructions
        search_type        = protocol_configuration.value.search_type
        supported_versions = protocol_configuration.value.supported_versions
      }
    }
  }

  # --- Interceptors ---
  dynamic "interceptor_configuration" {
    for_each = var.interceptor_configurations
    content {
      interception_points = interceptor_configuration.value.interception_points

      interceptor {
        lambda {
          arn = interceptor_configuration.value.interceptor.lambda_arn
        }
      }

      dynamic "input_configuration" {
        for_each = interceptor_configuration.value.input_configuration != null ? [interceptor_configuration.value.input_configuration] : []
        content {
          pass_request_headers = input_configuration.value.pass_request_headers
        }
      }
    }
  }

  tags = var.tags
}

################################################################################
# Bedrock AgentCore — Gateway Targets
################################################################################

resource "aws_bedrockagentcore_gateway_target" "this" {
  for_each = var.targets

  name               = each.value.name
  gateway_identifier = aws_bedrockagentcore_gateway.this.gateway_id
  description        = each.value.description

  target_configuration {
    mcp {
      # --- Lambda target ---
      dynamic "lambda" {
        for_each = each.value.lambda_configuration != null ? [each.value.lambda_configuration] : []
        content {
          lambda_arn = lambda.value.lambda_arn

          tool_schema {
            dynamic "inline_payload" {
              for_each = lambda.value.tool_definitions
              content {
                name        = inline_payload.value.name
                description = inline_payload.value.description

                input_schema {
                  type = inline_payload.value.input_schema_type
                }
              }
            }
          }
        }
      }

      # --- MCP Server target ---
      dynamic "mcp_server" {
        for_each = each.value.mcp_server_configuration != null ? [each.value.mcp_server_configuration] : []
        content {
          endpoint = mcp_server.value.endpoint
        }
      }
    }
  }

  dynamic "credential_provider_configuration" {
    for_each = each.value.credential_provider_configuration != null ? [each.value.credential_provider_configuration] : []
    content {
      dynamic "gateway_iam_role" {
        for_each = credential_provider_configuration.value.gateway_iam_role == true ? [1] : []
        content {}
      }

      dynamic "oauth" {
        for_each = credential_provider_configuration.value.oauth != null ? [credential_provider_configuration.value.oauth] : []
        content {
          provider_arn      = oauth.value.provider_arn
          scopes            = oauth.value.scopes
          custom_parameters = length(oauth.value.custom_parameters) > 0 ? oauth.value.custom_parameters : null
        }
      }

      dynamic "api_key" {
        for_each = credential_provider_configuration.value.api_key != null ? [credential_provider_configuration.value.api_key] : []
        content {
          provider_arn              = api_key.value.provider_arn
          credential_location       = api_key.value.credential_location
          credential_parameter_name = api_key.value.credential_parameter_name
          credential_prefix         = api_key.value.credential_prefix
        }
      }
    }
  }
}
