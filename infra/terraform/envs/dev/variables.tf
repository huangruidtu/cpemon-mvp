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

variable "vpc_cidr_block" {
  description = "IPv4 CIDR block for the dev EKS VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "eks_cluster_name" {
  description = "Name of the future dev EKS cluster. Used now for subnet discovery tags."
  type        = string
  default     = "cpemon-dev"
}

variable "eks_cluster_version" {
  description = "Optional Kubernetes version for the dev EKS cluster. Null lets AWS select the default supported version."
  type        = string
  default     = null
}

variable "eks_endpoint_public_access" {
  description = "Enable public EKS Kubernetes API endpoint access for dev."
  type        = bool
  default     = true
}

variable "eks_endpoint_private_access" {
  description = "Enable private EKS Kubernetes API endpoint access for dev."
  type        = bool
  default     = false
}

variable "eks_bootstrap_cluster_creator_admin_permissions" {
  description = "Grant implicit cluster admin to the IAM principal that creates the EKS cluster. Dev uses explicit access entries instead."
  type        = bool
  default     = false
}

variable "eks_access_entries" {
  description = "EKS access entries for human or automation IAM principals."
  type = map(object({
    principal_arn     = string
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
    kubernetes_groups = optional(list(string), [])
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        type       = string
        namespaces = optional(list(string), [])
      })
    })), {})
  }))
  default = {}
}

variable "subnet_availability_zones" {
  description = "Availability Zones used for dev public/private subnet pairs."
  type        = list(string)
  default = [
    "eu-north-1a",
    "eu-north-1b",
    "eu-north-1c",
  ]
}

variable "public_subnet_cidr_blocks" {
  description = "IPv4 CIDR blocks for dev public subnets."
  type        = list(string)
  default = [
    "10.40.0.0/24",
    "10.40.1.0/24",
    "10.40.2.0/24",
  ]
}

variable "private_subnet_cidr_blocks" {
  description = "IPv4 CIDR blocks for dev private subnets."
  type        = list(string)
  default = [
    "10.40.10.0/24",
    "10.40.11.0/24",
    "10.40.12.0/24",
  ]
}

variable "eks_node_group_name" {
  description = "Name of the primary dev EKS managed node group."
  type        = string
  default     = "cpemon-dev-ng-main"
}

variable "eks_node_capacity_type" {
  description = "Capacity type for dev EKS worker nodes: ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types allowed for dev EKS worker nodes."
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_disk_size" {
  description = "Root EBS volume size in GiB for each dev EKS worker node."
  type        = number
  default     = 20
}

variable "eks_node_desired_size" {
  description = "Initial desired number of dev EKS worker nodes."
  type        = number
  default     = 1
}

variable "eks_node_min_size" {
  description = "Minimum number of dev EKS worker nodes."
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of dev EKS worker nodes."
  type        = number
  default     = 2
}

variable "eks_node_max_unavailable" {
  description = "Maximum number of unavailable nodes during a dev EKS managed node group update."
  type        = number
  default     = 1
}

variable "enable_external_secrets_irsa" {
  description = "Create the IRSA IAM role and policy contract for External Secrets Operator."
  type        = bool
  default     = true
}

variable "external_secrets_role_name" {
  description = "IAM role name assumed by External Secrets Operator through IRSA."
  type        = string
  default     = "cpemon-dev-external-secrets-role"
}

variable "external_secrets_namespace" {
  description = "Kubernetes namespace where External Secrets Operator runs."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_service_account_name" {
  description = "Kubernetes service account name used by External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_secret_arns" {
  description = "Secrets Manager secret ARNs External Secrets Operator may read."
  type        = set(string)
  default     = []
}

variable "external_secrets_kms_key_arns" {
  description = "Customer managed KMS key ARNs External Secrets Operator may use for decrypting Secrets Manager secrets."
  type        = set(string)
  default     = []
}
