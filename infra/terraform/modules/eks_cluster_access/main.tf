resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  cluster_name      = var.cluster_name
  principal_arn     = each.value.principal_arn
  type              = each.value.type
  user_name         = each.value.user_name
  kubernetes_groups = each.value.kubernetes_groups
}

locals {
  policy_associations = merge(
    {},
    [
      for entry_key, entry in var.access_entries : {
        for association_key, association in entry.policy_associations :
        "${entry_key}.${association_key}" => {
          principal_arn = entry.principal_arn
          policy_arn    = association.policy_arn
          access_scope  = association.access_scope
        }
      }
    ]...
  )
}

resource "aws_eks_access_policy_association" "this" {
  for_each = local.policy_associations

  cluster_name  = var.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = each.value.access_scope.type
    namespaces = each.value.access_scope.namespaces
  }

  depends_on = [
    aws_eks_access_entry.this,
  ]
}
