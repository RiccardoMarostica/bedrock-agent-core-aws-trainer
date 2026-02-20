locals {
  enable_managed_policies = length(var.managed_policies) > 0
  enable_custom_policies  = length(var.custom_policies) > 0
}