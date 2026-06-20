locals {
  public_subnets = {
    for index, cidr_block in var.public_subnet_cidr_blocks : tostring(index) => {
      availability_zone = var.availability_zones[index]
      cidr_block        = cidr_block
      name              = "${var.name_prefix}-public-${var.availability_zones[index]}"
    }
  }

  private_subnets = {
    for index, cidr_block in var.private_subnet_cidr_blocks : tostring(index) => {
      availability_zone = var.availability_zones[index]
      cidr_block        = cidr_block
      name              = "${var.name_prefix}-private-${var.availability_zones[index]}"
    }
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = var.vpc_id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name                                        = each.value.name
      Tier                                        = "public"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                    = "1"
    }
  )
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = var.vpc_id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name                                        = each.value.name
      Tier                                        = "private"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"           = "1"
    }
  )
}
