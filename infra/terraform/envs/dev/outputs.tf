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

output "vpc_id" {
  description = "Dev EKS VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Dev EKS VPC CIDR block."
  value       = module.vpc.cidr_block
}

output "public_subnet_ids" {
  description = "Dev public subnet IDs for internet-facing load balancers."
  value       = module.vpc_subnets.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Dev private subnet IDs for EKS worker nodes and internal load balancers."
  value       = module.vpc_subnets.private_subnet_ids
}

output "public_subnet_ids_by_az" {
  description = "Dev public subnet IDs keyed by Availability Zone."
  value       = module.vpc_subnets.public_subnet_ids_by_az
}

output "private_subnet_ids_by_az" {
  description = "Dev private subnet IDs keyed by Availability Zone."
  value       = module.vpc_subnets.private_subnet_ids_by_az
}

output "eks_cluster_name" {
  description = "Dev EKS cluster name."
  value       = module.eks_cluster.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Dev EKS Kubernetes API endpoint."
  value       = module.eks_cluster.cluster_endpoint
}

output "eks_cluster_role_arn" {
  description = "IAM role ARN used by the dev EKS control plane."
  value       = module.eks_cluster.cluster_role_arn
}

output "eks_access_entry_principal_arns" {
  description = "IAM principal ARNs configured for dev EKS access."
  value       = module.eks_cluster_access.access_entry_principal_arns
}

output "eks_access_policy_association_keys" {
  description = "Configured dev EKS access policy association keys."
  value       = module.eks_cluster_access.access_policy_association_keys
}

output "eks_node_group_name" {
  description = "Primary dev EKS managed node group name."
  value       = module.eks_managed_node_group.node_group_name
}

output "eks_node_group_arn" {
  description = "Primary dev EKS managed node group ARN."
  value       = module.eks_managed_node_group.node_group_arn
}

output "eks_node_group_status" {
  description = "Primary dev EKS managed node group status."
  value       = module.eks_managed_node_group.node_group_status
}

output "eks_node_role_arn" {
  description = "IAM role ARN used by dev EKS worker nodes."
  value       = module.eks_managed_node_group.node_role_arn
}

output "eks_cluster_oidc_issuer_url" {
  description = "Dev EKS OIDC issuer URL used for IRSA trust policies."
  value       = module.eks_cluster.cluster_oidc_issuer_url
}

output "external_secrets_irsa_role_arn" {
  description = "IAM role ARN to annotate on the External Secrets Operator service account."
  value       = var.enable_external_secrets_irsa ? module.external_secrets_irsa[0].role_arn : null
}

output "eks_oidc_provider_arn" {
  description = "IAM OIDC provider ARN used by IRSA."
  value       = var.enable_external_secrets_irsa ? aws_iam_openid_connect_provider.eks[0].arn : null
}

output "external_secrets_irsa_policy_arn" {
  description = "Least-privilege IAM policy ARN attached to the ESO IRSA role."
  value       = var.enable_external_secrets_irsa ? module.external_secrets_irsa[0].policy_arn : null
}

output "external_secrets_service_account_subject" {
  description = "OIDC subject allowed to assume the ESO IRSA role."
  value       = var.enable_external_secrets_irsa ? module.external_secrets_irsa[0].service_account_subject : null
}
