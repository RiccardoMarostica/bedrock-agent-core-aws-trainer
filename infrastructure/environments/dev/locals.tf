locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id

  # Determine artifact mode: container vs code
  use_container = var.agent_use_container
  use_code      = !var.agent_use_container && length(var.agent_code_entry_points) > 0

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
