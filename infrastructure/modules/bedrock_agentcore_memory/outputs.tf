################################################################################
# Memory Outputs
################################################################################

output "memory_id" {
  description = "Unique identifier of the Memory."
  value       = aws_bedrockagentcore_memory.this.id
}

output "memory_arn" {
  description = "ARN of the Memory."
  value       = aws_bedrockagentcore_memory.this.arn
}

################################################################################
# Memory Strategy Outputs
################################################################################

output "strategy_ids" {
  description = "Map of strategy key to strategy ID."
  value       = { for k, v in aws_bedrockagentcore_memory_strategy.this : k => v.memory_strategy_id }
}
