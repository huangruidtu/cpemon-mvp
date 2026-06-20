locals {
  ecr_repository_names = toset([
    "acs-ingest",
    "cpemon-api",
    "cpemon-writer",
  ])
}

module "ecr_repositories" {
  source = "../../modules/ecr_repositories"

  repository_names = local.ecr_repository_names
}

module "github_ecr_push_role" {
  source = "../../modules/github_ecr_push_role"

  role_name           = var.github_ecr_push_role_name
  github_repository   = var.github_repository
  ecr_repository_arns = toset(values(module.ecr_repositories.repository_arns))
}
