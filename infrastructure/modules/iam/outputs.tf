output "arn" {
  description = "The ARN of the IAM Role"
  value       = aws_iam_role.role.arn
}

output "id" {
  description = "The ID of the IAM Role"
  value       = aws_iam_role.role.id
}

output "name" {
  description = "The name of the IAM Role"
  value       = aws_iam_role.role.name
}

output "custom_policy_arns" {
  description = "The ARNs of the custom IAM policies created"
  value       = aws_iam_policy.custom_policies[*].arn
}

output "custom_policy_ids" {
  description = "The IDs of the custom IAM policies created"
  value       = aws_iam_policy.custom_policies[*].id
}