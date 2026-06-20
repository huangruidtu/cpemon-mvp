variable "cluster_name" {
  description = "Name of the EKS cluster that owns this managed node group."
  type        = string
}

variable "node_group_name" {
  description = "Name of the EKS managed node group."
  type        = string
}

variable "node_role_name" {
  description = "IAM role name used by EC2 worker nodes in this managed node group."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs where worker nodes should run."
  type        = list(string)
}

variable "capacity_type" {
  description = "Capacity type for the managed node group: ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be either ON_DEMAND or SPOT."
  }
}

variable "instance_types" {
  description = "EC2 instance types allowed for worker nodes."
  type        = list(string)
  default     = ["t3.small"]
}

variable "disk_size" {
  description = "Root EBS volume size in GiB for each worker node."
  type        = number
  default     = 20
}

variable "desired_size" {
  description = "Initial desired number of worker nodes."
  type        = number
  default     = 1
}

variable "min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 2
}

variable "max_unavailable" {
  description = "Maximum number of unavailable nodes during a managed node group update."
  type        = number
  default     = 1
}

variable "labels" {
  description = "Kubernetes labels applied to nodes created by this managed node group."
  type        = map(string)
  default     = {}
}

variable "attach_vpc_cni_policy_to_node_role" {
  description = "Attach AmazonEKS_CNI_Policy to the node role until the aws-node service account has its own IRSA role."
  type        = bool
  default     = true
}
