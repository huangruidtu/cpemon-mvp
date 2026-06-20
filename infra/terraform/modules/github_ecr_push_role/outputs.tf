output "role_arn" {
  description = "IAM role ARN for GitHub Actions ECR publishing."
  value       = aws_iam_role.this.arn
}

output "policy_arn" {
  description = "Least-privilege ECR push policy ARN."
  value       = aws_iam_policy.ecr_push.arn
}
