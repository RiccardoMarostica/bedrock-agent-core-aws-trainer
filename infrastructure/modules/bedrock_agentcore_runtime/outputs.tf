################################################################################
# Agent Runtime Outputs
################################################################################

output "agent_runtime_id" {
  description = "Unique identifier of the Agent Runtime."
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
}

output "agent_runtime_arn" {
  description = "ARN of the Agent Runtime."
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
}

output "agent_runtime_version" {
  description = "Version of the Agent Runtime."
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_version
}

output "workload_identity_details" {
  description = "Workload identity details for the agent runtime."
  value       = aws_bedrockagentcore_agent_runtime.this.workload_identity_details
}

################################################################################
# Runtime Endpoint Outputs
################################################################################

output "endpoint_arn" {
  description = "ARN of the runtime endpoint."
  value       = var.create_endpoint ? aws_bedrockagentcore_agent_runtime_endpoint.this[0].agent_runtime_endpoint_arn : null
}

output "endpoint_runtime_arn" {
  description = "ARN of the agent runtime associated with the endpoint."
  value       = var.create_endpoint ? aws_bedrockagentcore_agent_runtime_endpoint.this[0].agent_runtime_arn : null
}
