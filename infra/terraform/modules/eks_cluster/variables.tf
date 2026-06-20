variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_role_name" {
  description = "IAM role name used by the EKS control plane."
  type        = string
}

variable "cluster_version" {
  description = "Optional Kubernetes version for the EKS cluster. Null lets AWS use the default supported version."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnet IDs used by the EKS control plane."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Enable public API endpoint access for the EKS cluster."
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Enable private API endpoint access inside the VPC."
  type        = bool
  default     = false
}

variable "authentication_mode" {
  description = "EKS cluster authentication mode. API uses EKS access entries instead of relying only on aws-auth."
  type        = string
  default     = "API"
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Grant the cluster creator admin permissions through EKS access management."
  type        = bool
  default     = true
}
