locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id

  # Determine artifact mode: container vs code
  use_container = var.agent_use_container
  use_code      = !var.agent_use_container && length(var.agent_code_entry_points) > 0

  # # AgentCore invocation URL: runtime ARN must be URL-encoded (colons → %3A, slashes → %2F)
  # aws_docs_mcp_runtime_arn_encoded = var.create_aws_docs_mcp_runtime && var.create_gateway ? replace(
  #   replace(
  #     module.aws_docs_mcp_runtime[0].agent_runtime_arn,
  #     ":", "%3A"
  #   ),
  #   "/", "%2F"
  # ) : ""
  # aws_docs_mcp_invocation_endpoint = var.create_aws_docs_mcp_runtime && var.create_gateway ? "https://bedrock-agentcore.${local.region}.amazonaws.com/runtimes/${local.aws_docs_mcp_runtime_arn_encoded}/invocations?qualifier=DEFAULT" : ""


  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
