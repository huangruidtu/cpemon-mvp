output "role_arn" {
  description = "IAM role ARN to annotate on the External Secrets Operator service account."
  value       = aws_iam_role.this.arn
}

output "policy_arn" {
  description = "Least-privilege IAM policy ARN attached to the ESO IRSA role."
  value       = aws_iam_policy.external_secrets.arn
}

output "service_account_subject" {
  description = "OIDC subject allowed to assume the ESO IRSA role."
  value       = local.service_account_sub
}
