output "user_pool_id" {
  description = "ID of the Cognito User Pool."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool."
  value       = aws_cognito_user_pool.this.arn
}

output "discovery_url" {
  description = "OIDC discovery URL for the Cognito User Pool."
  value       = "https://cognito-idp.${data.aws_region.current.id}.amazonaws.com/${aws_cognito_user_pool.this.id}/.well-known/openid-configuration"
}

output "resource_server_identifier" {
  description = "Resource server identifier (used as the JWT audience for client_credentials tokens)."
  value       = aws_cognito_resource_server.this.identifier
}

output "client_id" {
  description = "App client ID for M2M authentication."
  value       = aws_cognito_user_pool_client.this.id
}

output "client_secret" {
  description = "App client secret for M2M authentication."
  value       = aws_cognito_user_pool_client.this.client_secret
  sensitive   = true
}

output "scopes" {
  description = "Fully qualified scope strings (resource_server_id/scope_name)."
  value       = [for s in var.scopes : "${var.resource_server_identifier}/${s}"]
}

output "token_endpoint" {
  description = "Cognito token endpoint for client_credentials grant."
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.id}.amazoncognito.com/oauth2/token"
}

data "aws_region" "current" {}
