output "project_name" {
  description = "Project name used by the Terraform foundation."
  value       = var.project_name
}

output "environment" {
  description = "Terraform environment name."
  value       = var.environment
}

output "aws_region" {
  description = "AWS region configured for this environment."
  value       = var.aws_region
}

output "ecr_repository_urls" {
  description = "ECR repository URLs for CPEmon service images."
  value       = module.ecr_repositories.repository_urls
}

output "github_ecr_push_role_arn" {
  description = "GitHub Actions role ARN for ECR image publishing."
  value       = module.github_ecr_push_role.role_arn
}
