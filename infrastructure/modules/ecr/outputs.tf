output "repository_url" {
  description = "The URL of the ECR repository."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "Full ARN of the ECR repository."
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Name of the ECR repository."
  value       = aws_ecr_repository.this.name
}

output "registry_id" {
  description = "The registry ID where the repository was created."
  value       = aws_ecr_repository.this.registry_id
}
