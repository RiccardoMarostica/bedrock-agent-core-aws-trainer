################################################################################
# Gateway Outputs
################################################################################

output "gateway_id" {
  description = "Unique identifier of the Gateway."
  value       = aws_bedrockagentcore_gateway.this.gateway_id
}

output "gateway_arn" {
  description = "ARN of the Gateway."
  value       = aws_bedrockagentcore_gateway.this.gateway_arn
}

output "gateway_url" {
  description = "URL endpoint for the Gateway."
  value       = aws_bedrockagentcore_gateway.this.gateway_url
}

################################################################################
# Gateway Target Outputs
################################################################################

output "target_ids" {
  description = "Map of target key to target ID."
  value       = { for k, v in aws_bedrockagentcore_gateway_target.this : k => v.target_id }
}


