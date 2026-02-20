################################################################################
# Bedrock AgentCore — Workload Identity (Inbound)
################################################################################

resource "aws_bedrockagentcore_workload_identity" "this" {
  name = var.name

  allowed_resource_oauth2_return_urls = length(var.allowed_oauth2_return_urls) > 0 ? var.allowed_oauth2_return_urls : null
}

################################################################################
# Bedrock AgentCore — OAuth2 Credential Providers (Outbound)
################################################################################

resource "aws_bedrockagentcore_oauth2_credential_provider" "this" {
  for_each = var.oauth2_providers

  name                       = each.value.name
  credential_provider_vendor = each.value.vendor

  oauth2_provider_config {
    dynamic "google_oauth2_provider_config" {
      for_each = each.value.vendor == "GoogleOauth2" ? [1] : []
      content {
        client_id     = each.value.client_id
        client_secret = each.value.client_secret
      }
    }

    dynamic "github_oauth2_provider_config" {
      for_each = each.value.vendor == "GithubOauth2" ? [1] : []
      content {
        client_id     = each.value.client_id
        client_secret = each.value.client_secret
      }
    }

    dynamic "microsoft_oauth2_provider_config" {
      for_each = each.value.vendor == "MicrosoftOauth2" ? [1] : []
      content {
        client_id     = each.value.client_id
        client_secret = each.value.client_secret
      }
    }

    dynamic "slack_oauth2_provider_config" {
      for_each = each.value.vendor == "SlackOauth2" ? [1] : []
      content {
        client_id     = each.value.client_id
        client_secret = each.value.client_secret
      }
    }

    dynamic "custom_oauth2_provider_config" {
      for_each = each.value.vendor == "CustomOauth2" ? [1] : []
      content {
        client_id     = each.value.client_id
        client_secret = each.value.client_secret

        oauth_discovery {
          discovery_url = each.value.discovery_url
        }
      }
    }
  }
}

################################################################################
# Bedrock AgentCore — API Key Credential Providers (Outbound)
################################################################################

resource "aws_bedrockagentcore_api_key_credential_provider" "this" {
  for_each = var.api_key_providers

  name    = each.value.name
  api_key = each.value.api_key
}

################################################################################
# Bedrock AgentCore — Token Vault CMK (optional)
################################################################################

resource "aws_bedrockagentcore_token_vault_cmk" "this" {
  count = var.token_vault_kms_key_arn != null ? 1 : 0

  kms_configuration {
    key_type    = "CustomerManagedKey"
    kms_key_arn = var.token_vault_kms_key_arn
  }

  # aws_bedrockagentcore_token_vault_cmk does not support tags.
}
