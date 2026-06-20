# EKS Provisioning Foundation Review

## Why This Review Exists

This review closes the `CCPU-4` EKS provisioning foundation.

The earlier notes explain individual pieces: VPC, subnets, EKS cluster, managed node group, access entries, and kubeconfig. This page connects them into one mental model so the whole migration story is easier to review and explain in an interview.

The most important thing to remember:

```text
We have built and validated Terraform plans.
We have not run terraform apply for EKS resources yet.
```

That means no EKS control plane, no worker nodes, and no real `kubectl get nodes` result exist in AWS yet.

## Current State

Completed as code:

- Terraform remote backend with S3 and DynamoDB locking.
- Existing ECR repositories imported into Terraform state.
- GitHub OIDC role for ECR image publishing.
- VPC module for the future EKS network boundary.
- Public/private subnet module with EKS discovery tags.
- EKS cluster module.
- EKS managed node group module.
- EKS access entry module.
- kubeconfig and kubectl post-apply runbook/script.

Completed as validation:

- `terraform fmt -recursive`
- `terraform validate`
- backend-backed `terraform plan`

Deferred:

- `terraform apply`
- paid EKS control plane creation
- paid EC2 worker node creation
- live kubeconfig generation
- live `kubectl get nodes`
- application migration onto EKS

## Resource Dependency Map

The dependency chain is:

```text
remote state
  -> provider/profile
  -> VPC
  -> public/private subnets
  -> EKS cluster IAM role
  -> EKS cluster
  -> node IAM role
  -> managed node group
  -> EKS access entry
  -> kubeconfig
  -> kubectl validation
```

Terraform expresses this through module references:

```hcl
module.vpc_subnets.private_subnet_ids
module.eks_cluster.cluster_name
module.eks_managed_node_group.node_group_name
module.eks_cluster_access.access_entry_principal_arns
```

The key learning point is that Terraform does not need us to manually say "create VPC first" for every relationship. If one resource uses another resource's output, Terraform builds the graph.

## Terraform Files

Environment root:

```text
infra/terraform/envs/dev
```

Important files:

- `versions.tf`: pins Terraform and provider requirements.
- `providers.tf`: configures AWS region/profile and default tags.
- `backend.tf`: configures S3 remote state and DynamoDB locking.
- `variables.tf`: declares environment inputs.
- `terraform.tfvars.example`: safe example input values.
- `main.tf`: wires modules together.
- `outputs.tf`: exposes useful values.

Reusable modules:

- `modules/vpc`
- `modules/vpc_subnets`
- `modules/eks_cluster`
- `modules/eks_managed_node_group`
- `modules/eks_cluster_access`
- `modules/ecr_repositories`
- `modules/github_ecr_push_role`

## VPC

The VPC is the AWS network boundary for EKS.

Current dev CIDR:

```text
10.40.0.0/16
```

Why this matters:

- EKS control plane connects to the VPC.
- Worker nodes run inside the VPC.
- Load balancers are created inside subnets.
- Pod networking depends on VPC CNI behavior.

The VPC module enables DNS support and DNS hostnames because EKS and Kubernetes integrations commonly rely on AWS DNS behavior.

## Subnets

We created three public subnets and three private subnets across three Availability Zones.

Public:

```text
10.40.0.0/24  eu-north-1a
10.40.1.0/24  eu-north-1b
10.40.2.0/24  eu-north-1c
```

Private:

```text
10.40.10.0/24  eu-north-1a
10.40.11.0/24  eu-north-1b
10.40.12.0/24  eu-north-1c
```

The public subnet tags prepare for internet-facing load balancers:

```text
kubernetes.io/role/elb = 1
```

The private subnet tags prepare for internal load balancers:

```text
kubernetes.io/role/internal-elb = 1
```

Both subnet types have the cluster discovery tag:

```text
kubernetes.io/cluster/cpemon-dev = shared
```

`shared` means the subnet is associated with the cluster but not exclusively owned by the cluster.

## EKS Cluster

The EKS cluster is the managed Kubernetes control plane.

It creates:

- EKS cluster IAM role.
- Trust policy for `eks.amazonaws.com`.
- `AmazonEKSClusterPolicy` attachment.
- `aws_eks_cluster`.

Dev settings:

```text
cluster_name = cpemon-dev
authentication_mode = API
endpoint_public_access = true
endpoint_private_access = false
bootstrap_cluster_creator_admin_permissions = false
```

Why `authentication_mode = API`:

- Access can be managed through EKS access entries.
- We avoid depending on the legacy `aws-auth` ConfigMap as the primary access model.

Why public endpoint is enabled for dev:

- It makes early operator validation from a laptop easier.
- Production hardening can later restrict public CIDRs or enable private-only endpoint access.

Why bootstrap creator admin is disabled:

- We want explicit access entries instead of hidden implicit admin access.
- It avoids duplicate access entry conflicts for the same IAM principal.

## Managed Node Group

The managed node group creates EC2 worker nodes for EKS.

It creates:

- Node IAM role.
- Trust policy for `ec2.amazonaws.com`.
- `AmazonEKSWorkerNodePolicy`.
- `AmazonEC2ContainerRegistryPullOnly`.
- temporary `AmazonEKS_CNI_Policy`.
- `aws_eks_node_group`.

Dev sizing:

```text
capacity_type = ON_DEMAND
instance_types = ["t3.small"]
desired_size = 1
min_size = 1
max_size = 2
disk_size = 20
```

Why private subnets:

- Worker nodes should not be directly public.
- Public access should come through controlled load balancers or ingress.

Why CNI policy is currently on node role:

- We have not yet created IRSA or EKS Pod Identity for the `aws-node` service account.
- A later hardening step should move CNI permissions from node role to a service account role.

## Cluster Access

Cluster access is managed through:

- `aws_eks_access_entry`
- `aws_eks_access_policy_association`

Current admin principal:

```text
arn:aws:iam::701573843911:role/aws-reserved/sso.amazonaws.com/eu-north-1/AWSReservedSSO_CPEmonTerraformBootstrap_0241ccdc62503c71
```

Current access policy:

```text
arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy
```

Important distinction:

- IAM permission lets a role call AWS APIs.
- EKS access policy lets an authenticated IAM principal do Kubernetes actions inside the cluster.

You can have one without the other, and things will fail in different ways.

## kubeconfig and kubectl

`kubeconfig` is local operator state. It is not Terraform state.

After apply, use:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\eks-kubeconfig-check.ps1 -WriteKubeconfig
```

Equivalent AWS command:

```powershell
aws eks update-kubeconfig `
  --region eu-north-1 `
  --name cpemon-dev `
  --profile cpemon-terraform `
  --alias cpemon-dev
```

Validation commands:

```powershell
kubectl config current-context
kubectl cluster-info
kubectl get namespaces
kubectl get nodes -o wide
```

Current local blockers:

- `kubectl` is not installed or not in PATH.
- EKS cluster has not been applied yet.

## Permissions We Discovered

The bootstrap permission set started narrow and expanded as Terraform needed specific actions.

Important permission categories:

- S3 backend read/write.
- DynamoDB state locking.
- ECR repository read/tag.
- IAM role/policy management for GitHub ECR push role.
- EC2 VPC/subnet describe/create/tag.
- EKS cluster create/describe/tag/delete.
- IAM pass role to EKS.
- Node role management and policy attachment.
- EKS node group management.
- EKS access entry and access policy association management.

Interview point:

```text
The goal was not to make Terraform admin. The goal was to add the smallest permission needed for the next managed boundary.
```

## Plan-Only Boundary

We repeatedly chose `terraform plan`, not `terraform apply`.

Reasons:

- EKS control plane costs money after creation.
- Managed node group creates EC2 cost.
- Network egress design is not complete yet.
- Live kubeconfig validation requires a real cluster.
- We want one deliberate apply window with cleanup/runbook ready.

This is a professional decision, not a lack of progress.

## Future Apply Checklist

Before apply:

- Confirm AWS SSO login.
- Confirm `kubectl` is installed.
- Confirm bootstrap permission set has required EKS, EC2, and IAM permissions.
- Confirm Terraform plan still says only expected resources will be created.
- Confirm cost window and cleanup plan.

Apply:

```powershell
cd infra\terraform\envs\dev
terraform plan -var-file="terraform.tfvars.example"
terraform apply -var-file="terraform.tfvars.example"
```

After apply:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\..\scripts\eks-kubeconfig-check.ps1 -WriteKubeconfig
```

Then check:

```powershell
kubectl get namespaces
kubectl get nodes -o wide
```

## What To Say In An Interview

I built an EKS provisioning foundation with Terraform in small reviewable steps. I started from remote state and least-privilege AWS access, then added a VPC, public/private subnets, EKS cluster, managed node group, explicit EKS access entries, and a kubeconfig validation runbook. I kept it plan-only because creating EKS and EC2 resources has real cost and because I wanted the access, node group, and validation process ready before apply. The result is not just code; it is an operator-ready migration foundation with documentation, permissions notes, and troubleshooting paths.
