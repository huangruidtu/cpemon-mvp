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
