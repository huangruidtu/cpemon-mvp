output "access_entry_principal_arns" {
  description = "IAM principal ARNs configured as EKS access entries."
  value = {
    for key, entry in aws_eks_access_entry.this : key => entry.principal_arn
  }
}

output "access_policy_association_keys" {
  description = "Stable keys for EKS access policy associations."
  value       = keys(aws_eks_access_policy_association.this)
}
