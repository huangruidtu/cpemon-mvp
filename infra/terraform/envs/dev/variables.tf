variable "project_name" {
  description = "Project name used for tagging and naming CPEmon cloud platform resources."
  type        = string
  default     = "cpemon"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for the dev environment."
  type        = string
}

variable "aws_profile" {
  description = "Local AWS CLI profile used for Terraform operations."
  type        = string
  default     = "default"
}

variable "github_repository" {
  description = "GitHub repository allowed to publish CPEmon images, in owner/repo format."
  type        = string
}

variable "github_ecr_push_role_name" {
  description = "IAM role name assumed by GitHub Actions for ECR image publishing."
  type        = string
  default     = "cpemon-ci-github-role"
}
