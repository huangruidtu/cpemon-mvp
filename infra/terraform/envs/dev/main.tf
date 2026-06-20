locals {
  ecr_repository_names = toset([
    "acs-ingest",
    "cpemon-api",
    "cpemon-writer",
  ])

  name_prefix = "${var.project_name}-${var.environment}"

  subnet_availability_zones = var.subnet_availability_zones
}

module "vpc" {
  source = "../../modules/vpc"

  name       = "${local.name_prefix}-vpc"
  cidr_block = var.vpc_cidr_block
}

module "vpc_subnets" {
  source = "../../modules/vpc_subnets"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  cluster_name               = var.eks_cluster_name
  availability_zones         = local.subnet_availability_zones
  public_subnet_cidr_blocks  = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks
}

module "eks_cluster" {
  source = "../../modules/eks_cluster"

  cluster_name            = var.eks_cluster_name
  cluster_role_name       = "${local.name_prefix}-eks-cluster-role"
  cluster_version         = var.eks_cluster_version
  subnet_ids              = module.vpc_subnets.private_subnet_ids
  endpoint_public_access  = var.eks_endpoint_public_access
  endpoint_private_access = var.eks_endpoint_private_access

  bootstrap_cluster_creator_admin_permissions = var.eks_bootstrap_cluster_creator_admin_permissions
}

module "eks_managed_node_group" {
  source = "../../modules/eks_managed_node_group"

  cluster_name    = module.eks_cluster.cluster_name
  node_group_name = var.eks_node_group_name
  node_role_name  = "${local.name_prefix}-eks-node-role"
  subnet_ids      = module.vpc_subnets.private_subnet_ids
  capacity_type   = var.eks_node_capacity_type
  instance_types  = var.eks_node_instance_types
  disk_size       = var.eks_node_disk_size
  desired_size    = var.eks_node_desired_size
  min_size        = var.eks_node_min_size
  max_size        = var.eks_node_max_size
  max_unavailable = var.eks_node_max_unavailable

  labels = {
    environment = var.environment
    project     = var.project_name
  }
}

module "eks_cluster_access" {
  source = "../../modules/eks_cluster_access"

  cluster_name   = module.eks_cluster.cluster_name
  access_entries = var.eks_access_entries
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
