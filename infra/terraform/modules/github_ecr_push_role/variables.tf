variable "role_name" {
  description = "IAM role name assumed by GitHub Actions for ECR image publishing."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the role, in owner/repo format."
  type        = string
}

variable "allowed_refs" {
  description = "Git refs allowed to assume this role through GitHub OIDC."
  type        = set(string)
  default     = ["refs/heads/main", "refs/tags/v*"]
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs this role can push to."
  type        = set(string)
}
