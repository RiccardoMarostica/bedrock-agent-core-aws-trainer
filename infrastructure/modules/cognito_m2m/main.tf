################################################################################
# Cognito User Pool — Machine-to-Machine (M2M) OAuth2
#
# Creates a User Pool with a resource server and an M2M app client that uses
# client_credentials grant. Used for Gateway → MCP Runtime outbound auth.
################################################################################

resource "aws_cognito_user_pool" "this" {
  name = var.user_pool_name

  tags = var.tags
}

# Domain is required for the token endpoint
resource "aws_cognito_user_pool_domain" "this" {
  domain       = var.user_pool_name
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_resource_server" "this" {
  identifier   = var.resource_server_identifier
  name         = var.resource_server_name
  user_pool_id = aws_cognito_user_pool.this.id

  dynamic "scope" {
    for_each = var.scopes
    content {
      scope_name        = scope.value
      scope_description = "Scope: ${scope.value}"
    }
  }
}

resource "aws_cognito_user_pool_client" "this" {
  name         = var.client_name
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret              = true
  allowed_oauth_flows          = ["client_credentials"]
  allowed_oauth_scopes         = [for s in var.scopes : "${var.resource_server_identifier}/${s}"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers = ["COGNITO"]

  explicit_auth_flows = []

  depends_on = [aws_cognito_resource_server.this]
}
