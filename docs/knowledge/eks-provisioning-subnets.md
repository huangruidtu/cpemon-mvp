# EKS Provisioning with Terraform - Public and Private Subnets

## Why This Subtask Exists

`CCPU-38` creates the subnet layer inside the dev VPC.

The VPC gives CPEmon a private AWS network boundary. Subnets split that network into smaller address ranges placed in specific Availability Zones. EKS needs subnets because worker nodes, load balancers, and later platform components must run in concrete network locations.

## Public vs Private Subnets

A public subnet is intended for resources that can be reached from the internet through an internet gateway and route table.

A private subnet is intended for resources that should not receive direct public internet traffic.

For EKS, a common pattern is:

- Public subnets for internet-facing load balancers.
- Private subnets for worker nodes and internal load balancers.

This task creates the subnets and tags them for EKS discovery. It does not create route tables, an internet gateway, or NAT. Those routing decisions are separate tasks.

## Dev Subnet Layout

The dev environment uses three Availability Zones in `eu-north-1`:

```text
eu-north-1a
eu-north-1b
eu-north-1c
```

Public subnets:

```text
10.40.0.0/24  -> eu-north-1a
10.40.1.0/24  -> eu-north-1b
10.40.2.0/24  -> eu-north-1c
```

Private subnets:

```text
10.40.10.0/24 -> eu-north-1a
10.40.11.0/24 -> eu-north-1b
10.40.12.0/24 -> eu-north-1c
```

All subnet CIDRs are carved from the VPC CIDR:

```text
10.40.0.0/16
```

## Why Three Availability Zones

EKS can run across multiple Availability Zones. Spreading subnets across three AZs prepares the platform for better failure isolation than a single-AZ layout.

For a small dev environment, three AZs may be more than strictly necessary, but it is useful for learning a production-style topology.

## Terraform Module

The subnet implementation lives in:

```text
infra/terraform/modules/vpc_subnets
```

The dev environment calls it from:

```text
infra/terraform/envs/dev/main.tf
```

The module creates:

- `aws_subnet.public`
- `aws_subnet.private`

Both resources use `for_each`, so Terraform creates one subnet per CIDR/AZ pair.

## Important Terraform Blocks

### public_subnets local

```hcl
public_subnets = {
  for index, cidr_block in var.public_subnet_cidr_blocks : tostring(index) => {
    availability_zone = var.availability_zones[index]
    cidr_block        = cidr_block
    name              = "${var.name_prefix}-public-${var.availability_zones[index]}"
  }
}
```

This transforms a list of CIDR blocks into a map Terraform can use with `for_each`.

The key is the list index: `"0"`, `"1"`, `"2"`.

Each value contains:

- The Availability Zone.
- The CIDR block.
- The generated subnet name.

### aws_subnet.public

```hcl
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = var.vpc_id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = true
}
```

This creates public subnets.

`map_public_ip_on_launch = true` means EC2 instances launched into the subnet can automatically receive public IP addresses. This does not make the subnet fully public by itself. A public route through an internet gateway is also required, and that is intentionally not part of this task.

### aws_subnet.private

```hcl
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = var.vpc_id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false
}
```

This creates private subnets.

`map_public_ip_on_launch = false` means instances launched into the subnet do not automatically receive public IPs.

## EKS Subnet Tags

EKS and AWS load balancer integrations use subnet tags to discover which subnets should be used for which type of load balancer.

All subnets receive:

```text
kubernetes.io/cluster/cpemon-dev = shared
```

This says the subnets are associated with the future `cpemon-dev` EKS cluster but are not owned exclusively by that cluster.

Public subnets receive:

```text
kubernetes.io/role/elb = 1
```

This marks them for internet-facing load balancers.

Private subnets receive:

```text
kubernetes.io/role/internal-elb = 1
```

This marks them for internal load balancers.

## What This Task Does Not Do

This task does not create:

- Internet gateway.
- NAT gateway.
- Route tables.
- Route table associations.
- EKS cluster.
- EKS node group.

Subnets define where resources can live. Route tables define how traffic moves. Keeping those separate makes the network easier to reason about.

## Validation Result

After `terraform init` and `terraform validate`, the real backend-backed plan succeeded:

```text
Plan: 7 to add, 0 to change, 0 to destroy.
```

The planned resources are:

```text
module.vpc.aws_vpc.this
module.vpc_subnets.aws_subnet.public["0"]
module.vpc_subnets.aws_subnet.public["1"]
module.vpc_subnets.aws_subnet.public["2"]
module.vpc_subnets.aws_subnet.private["0"]
module.vpc_subnets.aws_subnet.private["1"]
module.vpc_subnets.aws_subnet.private["2"]
```

The plan is expected to include the VPC because `CCPU-37` has been planned but not applied yet. Terraform will create the VPC first, then create subnets using `module.vpc.vpc_id`.

## Permission Learning

The first implementation used `data "aws_availability_zones"` to discover AZs dynamically. The plan failed because the Terraform SSO role did not have:

```text
ec2:DescribeAvailabilityZones
```

The implementation was changed to explicit dev AZ inputs:

```hcl
subnet_availability_zones = [
  "eu-north-1a",
  "eu-north-1b",
  "eu-north-1c",
]
```

This keeps the plan working with the current permission set and makes the learning path visible. In a larger platform, dynamic AZ lookup is convenient, but the operator role must have the required describe permission.

## Manual Permission Set Update

At this stage, the `CPEmonTerraformBootstrap` IAM Identity Center permission set is treated as an external cloud foundation dependency. It is not managed inside the CPEmon platform Terraform repo yet.

Before applying the VPC/subnet Terraform, update the permission set inline policy with EC2 networking permissions.

Add this statement to the existing inline policy `Statement` array:

```json
{
  "Sid": "ManageCpemonDevVpcAndSubnets",
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeVpcs",
    "ec2:DescribeSubnets",
    "ec2:DescribeRouteTables",
    "ec2:DescribeInternetGateways",
    "ec2:DescribeNatGateways",
    "ec2:DescribeSecurityGroups",
    "ec2:DescribeAvailabilityZones",
    "ec2:DescribeNetworkAcls",
    "ec2:DescribeTags",
    "ec2:CreateVpc",
    "ec2:CreateSubnet",
    "ec2:CreateTags",
    "ec2:DeleteTags",
    "ec2:ModifyVpcAttribute",
    "ec2:DeleteSubnet",
    "ec2:DeleteVpc"
  ],
  "Resource": "*",
  "Condition": {
    "StringEqualsIfExists": {
      "aws:RequestedRegion": "eu-north-1"
    }
  }
}
```

Why `Resource = "*"` is used here:

Many EC2 networking actions, especially describe actions and some create operations, do not support resource-level permissions in the same clean way that ECR or IAM role actions do. The permission is still constrained by region using `aws:RequestedRegion`.

This is still not a broad administrator policy. It is limited to EC2 networking actions needed for the VPC/subnet provisioning path in `eu-north-1`.

After saving the permission set, re-login so the local SSO session receives the updated permissions:

```bash
aws sso login --profile cpemon-terraform
aws sts get-caller-identity --profile cpemon-terraform
```

Then rerun:

```bash
terraform plan -var-file="terraform.tfvars.example"
```

## Interview Explanation

After creating the VPC module, I added a subnet module that creates public and private subnet pairs across three Availability Zones. Public subnets are tagged for internet-facing load balancers, and private subnets are tagged for internal load balancers and future worker node placement. I intentionally kept routing resources out of this task so the subnet layer and routing layer can be reviewed separately.
