variable "name_prefix" {
  description = "Prefix used for subnet Name tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the subnets are created."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name used in Kubernetes subnet discovery tags."
  type        = string
}

variable "availability_zones" {
  description = "Availability Zones used for the public/private subnet pairs."
  type        = list(string)
}

variable "public_subnet_cidr_blocks" {
  description = "CIDR blocks for public subnets. Must align by index with availability_zones."
  type        = list(string)
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets. Must align by index with availability_zones."
  type        = list(string)
}

variable "tags" {
  description = "Additional tags applied to all subnets."
  type        = map(string)
  default     = {}
}
