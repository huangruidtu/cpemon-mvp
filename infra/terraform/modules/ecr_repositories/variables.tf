variable "repository_names" {
  description = "ECR repository names used by CPEmon services."
  type        = set(string)
}

variable "image_tag_mutability" {
  description = "ECR image tag mutability. Keep MUTABLE while the MVP workflow still publishes latest."
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable ECR basic image scanning on push."
  type        = bool
  default     = false
}
