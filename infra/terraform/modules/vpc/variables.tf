variable "name" {
  description = "Name tag for the VPC."
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR block allocated to the VPC."
  type        = string
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC. EKS workloads and AWS integrations commonly depend on this."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS resolution in the VPC. Keep enabled for EKS and AWS service discovery."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to the VPC."
  type        = map(string)
  default     = {}
}
