output "node_group_name" {
  description = "EKS managed node group name."
  value       = aws_eks_node_group.this.node_group_name
}

output "node_group_arn" {
  description = "EKS managed node group ARN."
  value       = aws_eks_node_group.this.arn
}

output "node_group_status" {
  description = "Current EKS managed node group status."
  value       = aws_eks_node_group.this.status
}

output "node_role_name" {
  description = "IAM role name used by the worker nodes."
  value       = aws_iam_role.node.name
}

output "node_role_arn" {
  description = "IAM role ARN used by the worker nodes."
  value       = aws_iam_role.node.arn
}
