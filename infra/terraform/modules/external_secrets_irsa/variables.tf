variable "role_name" {
  description = "IAM role name assumed by the External Secrets Operator service account."
  type        = string
}

variable "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for the EKS cluster."
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC issuer URL, for example https://oidc.eks.eu-north-1.amazonaws.com/id/EXAMPLE."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where External Secrets Operator runs."
  type        = string
  default     = "external-secrets"
}

variable "service_account_name" {
  description = "Kubernetes service account name used by External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "secret_arns" {
  description = "Secrets Manager secret ARNs ESO may read."
  type        = set(string)
}

variable "kms_key_arns" {
  description = "Optional KMS key ARNs needed to decrypt Secrets Manager secrets protected by customer managed keys."
  type        = set(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to ESO IAM resources."
  type        = map(string)
  default     = {}
}
