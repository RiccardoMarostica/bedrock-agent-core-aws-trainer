################################################################################
# Workload Identity Outputs
################################################################################

output "workload_identity_arn" {
  description = "ARN of the AgentCore Workload Identity."
  value       = aws_bedrockagentcore_workload_identity.this.workload_identity_arn
}

################################################################################
# JWT Authorizer Config Output (pass-through — no resource)
################################################################################

output "jwt_authorizer_config" {
  description = <<-EOT
    Pass-through of the jwt_authorizer input variable. Feed this into the
    runtime module's authorizer_configuration to enable JWT inbound auth.
    Null when var.jwt_authorizer is not set.
  EOT
  value       = var.jwt_authorizer
}

################################################################################
# OAuth2 Credential Provider Outputs
################################################################################

output "oauth2_provider_arns" {
  description = "Map of oauth2_providers key to credential provider ARN. Feed into gateway target credential_provider_configuration.oauth.provider_arn."
  value       = { for k, v in aws_bedrockagentcore_oauth2_credential_provider.this : k => v.credential_provider_arn }
}

################################################################################
# API Key Credential Provider Outputs
################################################################################

output "api_key_provider_arns" {
  description = "Map of api_key_providers key to credential provider ARN. Feed into gateway target credential_provider_configuration.api_key.provider_arn."
  value       = { for k, v in aws_bedrockagentcore_api_key_credential_provider.this : k => v.credential_provider_arn }
}
