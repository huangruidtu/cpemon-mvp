variable "cluster_name" {
  description = "EKS cluster name that receives access entries."
  type        = string
}

variable "access_entries" {
  description = "EKS access entries keyed by a stable local name."
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
