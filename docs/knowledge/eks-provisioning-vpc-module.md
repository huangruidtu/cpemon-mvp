# EKS Provisioning with Terraform - VPC Module

## Why This Subtask Exists

`CCPU-37` creates the first AWS networking building block for the EKS migration: the VPC.

In the MVP, Kubernetes runs in a local or lab-style environment where networking is mostly provided by the existing machine or cluster setup. In EKS, Kubernetes runs inside AWS networking. That means the cluster, worker nodes, load balancers, and later platform add-ons all depend on VPC design.

The VPC is the boundary for the AWS network. Later subtasks will place public subnets, private subnets, route tables, NAT, EKS control plane networking, and worker nodes inside this VPC.

## What A VPC Is

A VPC is a private network inside an AWS region.

For this project, think of it as:

- The AWS network container for the CPEmon dev EKS platform.
- The place where EKS worker nodes will eventually run.
- The network boundary where subnets, route tables, gateways, and security groups will be attached.

The VPC does not run applications by itself. It creates the network space where later resources can live.

## Why Terraform Needs A VPC Module

The project could create `aws_vpc` directly inside `infra/terraform/envs/dev/main.tf`, but a module gives us a reusable and understandable boundary.

The module keeps the VPC logic in:

```text
infra/terraform/modules/vpc
```

The dev environment calls it from:

```text
infra/terraform/envs/dev/main.tf
```

This separation teaches an important Terraform pattern:

- `modules/` contains reusable infrastructure building blocks.
- `envs/dev/` decides which modules are used for the dev environment.

## Files Created

```text
infra/terraform/modules/vpc/
  main.tf
  variables.tf
  outputs.tf
```

The module follows the same local style as the existing ECR and GitHub OIDC modules.

## Terraform Block By Block

### Resource: aws_vpc.this

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}
```

This block tells Terraform to create one AWS VPC.

`resource` means Terraform will manage a real infrastructure object.

`aws_vpc` is the AWS provider resource type.

`this` is the local Terraform name for this resource inside the module. The name `this` is common when a module manages one main object.

### cidr_block

```hcl
cidr_block = var.cidr_block
```

The CIDR block defines the private IP address range for the VPC.

The dev environment currently passes:

```hcl
vpc_cidr_block = "10.40.0.0/16"
```

That gives the VPC a large private range that can later be split into public and private subnets.

Important mental model:

- VPC CIDR is the big address space.
- Subnet CIDRs are smaller slices carved out of it.

Example later:

- VPC: `10.40.0.0/16`
- Public subnet A: `10.40.0.0/24`
- Private subnet A: `10.40.10.0/24`

We have not created subnets yet because that belongs to `CCPU-38`.

### enable_dns_hostnames

```hcl
enable_dns_hostnames = var.enable_dns_hostnames
```

This enables DNS hostnames for instances launched in the VPC.

For EKS, DNS support is normally kept enabled because worker nodes and workloads often need AWS DNS behavior. Turning this off can make AWS integrations harder to troubleshoot.

### enable_dns_support

```hcl
enable_dns_support = var.enable_dns_support
```

This enables DNS resolution in the VPC.

EKS and EC2 nodes need normal name resolution for AWS APIs, container registries, package repositories, and service endpoints.

For this project, the default is `true`.

### tags

```hcl
tags = merge(
  var.tags,
  {
    Name = var.name
  }
)
```

Tags are metadata on AWS resources.

This module always sets a `Name` tag from `var.name`. It also allows extra module-specific tags through `var.tags`.

The AWS provider already applies default tags from:

```text
infra/terraform/envs/dev/providers.tf
```

Those default tags are:

```hcl
Project     = var.project_name
Environment = var.environment
ManagedBy   = "terraform"
```

So the VPC will get both provider-level tags and the module-level `Name`.

## Variables

The module exposes variables instead of hard-coding values:

- `name`: Name tag for the VPC.
- `cidr_block`: IP range for the VPC.
- `enable_dns_hostnames`: whether DNS hostnames are enabled.
- `enable_dns_support`: whether DNS resolution is enabled.
- `tags`: optional extra tags.

This makes the module reusable and easier to test in different environments later.

## Outputs

The module exports:

- `vpc_id`
- `vpc_arn`
- `cidr_block`
- `default_security_group_id`

Outputs matter because later Terraform code needs to connect resources together.

For example, the subnet task will need:

```hcl
vpc_id = module.vpc.vpc_id
```

That is how Terraform builds a dependency graph. Subnets depend on the VPC output, so Terraform knows the VPC must exist before subnets can be created.

## Dev Environment Wiring

The dev root now has:

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
```

This produces a consistent name prefix such as:

```text
cpemon-dev
```

The VPC module call is:

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name       = "${local.name_prefix}-vpc"
  cidr_block = var.vpc_cidr_block
}
```

Line by line:

- `module "vpc"` creates one module instance named `vpc`.
- `source = "../../modules/vpc"` points to the local module folder.
- `name` becomes the AWS `Name` tag.
- `cidr_block` passes the dev VPC CIDR into the module.

## What This Subtask Intentionally Does Not Do

This subtask does not create:

- Public subnets.
- Private subnets.
- Internet gateway.
- NAT gateway.
- Route tables.
- EKS subnet tags.
- EKS cluster.
- EKS node group.

Those are intentionally left for later CCPU-4 subtasks. Keeping this step small makes the Terraform plan easier to read and teaches the foundation before adding EKS-specific complexity.

## Validation Commands

Run from the repository root:

```bash
terraform fmt -recursive infra/terraform
```

Run from:

```bash
cd infra/terraform/envs/dev
```

Then:

```bash
terraform init
terraform validate
terraform plan -var-file="terraform.tfvars.example"
```

For this subtask, the plan should include a new VPC resource:

```text
aws_vpc.this
```

Because the VPC is inside a module, Terraform will display it as:

```text
module.vpc.aws_vpc.this
```

In this implementation pass, syntax validation was confirmed with a clean local Terraform data directory:

```powershell
$env:TF_DATA_DIR="$env:TEMP\cpemon-tfdata-ccpu37"
terraform init -backend=false
terraform validate
```

This is useful when the real backend or AWS SSO session is not available but you still want to prove the Terraform code is structurally valid.

After refreshing the AWS SSO session, the real backend-backed plan also succeeded:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

The planned resource was:

```text
module.vpc.aws_vpc.this
```

Important plan details:

```text
cidr_block           = "10.40.0.0/16"
enable_dns_hostnames = true
enable_dns_support   = true
Name                 = "cpemon-dev-vpc"
```

This is exactly the expected result for `CCPU-37`: create the VPC foundation only, without creating subnets, route tables, NAT, or EKS resources yet.

## Common Errors

### Invalid CIDR Block

If the CIDR is malformed, Terraform or AWS will reject it.

Example bad value:

```hcl
vpc_cidr_block = "10.40.0.0"
```

Use a real CIDR:

```hcl
vpc_cidr_block = "10.40.0.0/16"
```

### Overlapping Network Ranges

If this VPC later needs to connect to another VPC, VPN, office network, or shared service network, overlapping CIDRs can become a serious problem.

For this demo dev environment, `10.40.0.0/16` is acceptable because the project is isolated. In a company, the CIDR would normally be chosen from an approved network allocation plan.

### Forgetting Outputs

If the module creates a VPC but does not output `vpc_id`, later subnet code cannot easily reference it.

Outputs are the clean way to connect module boundaries.

### AWS SSO Token Expired

During validation, the normal backend-backed Terraform command can fail with:

```text
No valid credential sources found
failed to refresh cached credentials
InvalidGrantException
```

This means the AWS SSO cached token is expired or cannot be refreshed.

Fix:

```bash
aws sso login --profile cpemon-terraform
aws sts get-caller-identity --profile cpemon-terraform
```

Then rerun:

```bash
terraform init
terraform plan -var-file="terraform.tfvars.example"
```

If you only need syntax validation and do not want to touch the S3 backend, use a clean temporary Terraform data directory:

```powershell
$env:TF_DATA_DIR="$env:TEMP\cpemon-tfdata-ccpu37"
terraform init -backend=false
terraform validate
```

### Missing EC2 Networking Read Permissions

When checking VPCs from the AWS CLI, this command failed:

```bash
aws ec2 describe-vpcs --region eu-north-1 --profile cpemon-terraform
```

The error was:

```text
UnauthorizedOperation: not authorized to perform: ec2:DescribeVpcs
```

This revealed an important platform permission requirement: the Terraform operator permission set needs EC2 networking read, create, and tagging permissions for the EKS networking tasks.

At minimum, the permission set needs describe access for plan/debug workflows:

```text
ec2:DescribeVpcs
ec2:DescribeSubnets
ec2:DescribeRouteTables
ec2:DescribeInternetGateways
ec2:DescribeNatGateways
ec2:DescribeSecurityGroups
ec2:DescribeAvailabilityZones
ec2:DescribeNetworkAcls
ec2:DescribeTags
```

For apply workflows, the permission set will also need scoped create/tag/delete permissions for the networking resources managed by Terraform, such as:

```text
ec2:CreateVpc
ec2:CreateSubnet
ec2:CreateTags
ec2:DeleteTags
ec2:ModifyVpcAttribute
ec2:DeleteVpc
ec2:DeleteSubnet
```

Later routing tasks will require additional permissions for internet gateways, route tables, and NAT gateways. Those should be added deliberately when those resources are introduced.

## Interview Explanation

For the first EKS provisioning step, I created a Terraform VPC module instead of placing the VPC directly in the environment root. The point was to establish a clean network boundary for the future EKS cluster while keeping the implementation understandable.

The VPC module creates the AWS network address space, enables DNS support for EKS compatibility, applies consistent tags, and exports outputs such as `vpc_id` so later subnet and EKS modules can depend on it. I intentionally kept subnets and routing out of this task because those are separate design steps with their own trade-offs.
