################################################################################
# S3
################################################################################

output "agent_code_bucket_name" {
  description = "Name of the S3 bucket for agent code artifacts."
  value       = module.agent_code_bucket.bucket_name
}

output "agent_code_bucket_arn" {
  description = "ARN of the S3 bucket for agent code artifacts."
  value       = module.agent_code_bucket.bucket_arn
}

################################################################################
# ECR
################################################################################

output "ecr_repository_url" {
  description = "URL of the ECR repository."
  value       = module.agent_ecr.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository."
  value       = module.agent_ecr.repository_name
}

################################################################################
# IAM
################################################################################

output "agentcore_runtime_role_arn" {
  description = "ARN of the AgentCore runtime IAM role."
  value       = module.agentcore_runtime_role.arn
}

################################################################################
# AgentCore Runtime (only when create_runtime = true)
################################################################################

output "agentcore_runtime_id" {
  description = "ID of the AgentCore agent runtime."
  value       = var.create_runtime ? module.agentcore_runtime[0].agent_runtime_id : null
}

output "agentcore_runtime_arn" {
  description = "ARN of the AgentCore agent runtime."
  value       = var.create_runtime ? module.agentcore_runtime[0].agent_runtime_arn : null
}

output "agentcore_endpoint_arn" {
  description = "ARN of the AgentCore runtime endpoint."
  value       = var.create_runtime ? module.agentcore_runtime[0].endpoint_arn : null
}

################################################################################
# AgentCore Memory (only when create_memory = true)
################################################################################

output "agentcore_memory_id" {
  description = "ID of the AgentCore Memory."
  value       = var.create_memory ? module.agentcore_memory[0].memory_id : null
}

output "agentcore_memory_arn" {
  description = "ARN of the AgentCore Memory."
  value       = var.create_memory ? module.agentcore_memory[0].memory_arn : null
}

output "agentcore_memory_strategy_ids" {
  description = "Map of strategy key to strategy ID."
  value       = var.create_memory ? module.agentcore_memory[0].strategy_ids : null
}

################################################################################
# AgentCore Identity (only when create_identity = true)
################################################################################

output "agentcore_workload_identity_arn" {
  description = "ARN of the AgentCore Workload Identity."
  value       = var.create_identity ? module.agentcore_identity[0].workload_identity_arn : null
}

output "agentcore_oauth2_provider_arns" {
  description = "Map of OAuth2 credential provider key to ARN."
  value       = var.create_identity ? module.agentcore_identity[0].oauth2_provider_arns : null
}

output "agentcore_api_key_provider_arns" {
  description = "Map of API key credential provider key to ARN."
  value       = var.create_identity ? module.agentcore_identity[0].api_key_provider_arns : null
}
