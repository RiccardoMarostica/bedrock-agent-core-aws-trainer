################################################################################
# Bedrock AgentCore — Memory
################################################################################

resource "aws_bedrockagentcore_memory" "this" {
  name                      = var.name
  event_expiry_duration     = var.event_expiry_duration
  description               = var.description
  encryption_key_arn        = var.encryption_key_arn
  memory_execution_role_arn = var.memory_execution_role_arn

  tags = var.tags
}

################################################################################
# Bedrock AgentCore — Memory Strategies
################################################################################

resource "aws_bedrockagentcore_memory_strategy" "this" {
  for_each = var.strategies

  name        = each.value.name
  memory_id   = aws_bedrockagentcore_memory.this.id
  type        = each.value.type
  namespaces  = each.value.namespaces
  description = each.value.description
}
