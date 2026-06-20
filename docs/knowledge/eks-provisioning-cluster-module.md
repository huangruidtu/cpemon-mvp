# EKS Provisioning with Terraform - Cluster Module

## Why This Subtask Exists

`CCPU-39` creates the Terraform module for the EKS control plane.

The VPC and subnets provide the AWS network foundation. The EKS cluster module creates the managed Kubernetes control plane that will later host CPEmon workloads through managed node groups and GitOps.

This task does not create worker nodes. That belongs to the managed node group task.

## What EKS Manages

EKS manages the Kubernetes control plane:

- Kubernetes API server.
- Control plane availability.
- Control plane patching and managed lifecycle.
- Integration with AWS IAM and VPC networking.

The project still manages:

- VPC and subnets.
- Worker nodes or node groups.
- Kubernetes add-ons.
- Application deployment model.
- Access policies.
- Cost and cleanup process.

## Terraform Module

The implementation lives in:

```text
infra/terraform/modules/eks_cluster
```

The dev environment calls it from:

```text
infra/terraform/envs/dev/main.tf
```

The module creates:

- EKS cluster IAM role.
- IAM trust policy for `eks.amazonaws.com`.
- Attachment to AWS managed policy `AmazonEKSClusterPolicy`.
- EKS cluster control plane.

## Important Terraform Blocks

### Cluster Assume Role Policy

```hcl
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}
```

This policy answers: who is allowed to assume the cluster IAM role?

The answer is the EKS service itself:

```text
eks.amazonaws.com
```

Without this trust policy, EKS could not use the role.

### Cluster IAM Role

```hcl
resource "aws_iam_role" "cluster" {
  name               = var.cluster_role_name
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
}
```

This creates the IAM role used by the EKS control plane.

The role name in dev is:

```text
cpemon-dev-eks-cluster-role
```

### AmazonEKSClusterPolicy Attachment

```hcl
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
```

AWS documentation says an EKS cluster IAM role is required, and `AmazonEKSClusterPolicy` is one of the policies used for the cluster role.

This policy gives the EKS service the AWS permissions it needs to manage cluster-related resources on behalf of the control plane.

### EKS Cluster Resource

```hcl
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version
}
```

This creates the EKS control plane.

The version is optional:

```hcl
cluster_version = null
```

Null means AWS can use the default supported version. This avoids hard-coding a Kubernetes version before we are ready to discuss upgrade policy.

### Access Config

```hcl
access_config {
  authentication_mode                         = var.authentication_mode
  bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
}
```

The dev module uses:

```text
authentication_mode = API
bootstrap_cluster_creator_admin_permissions = true
```

This prepares the cluster for the newer EKS access management model rather than relying only on the legacy `aws-auth` ConfigMap.

Detailed access entries are intentionally left for the cluster access task.

### VPC Config

```hcl
vpc_config {
  subnet_ids              = var.subnet_ids
  endpoint_private_access = var.endpoint_private_access
  endpoint_public_access  = var.endpoint_public_access
}
```

The cluster is connected to the private subnets:

```hcl
subnet_ids = module.vpc_subnets.private_subnet_ids
```

For dev, the API endpoint is public:

```text
endpoint_public_access = true
endpoint_private_access = false
```

This keeps early kubectl access simpler. Later hardening can restrict public CIDRs or enable private endpoint access.

## What This Task Does Not Do

This task does not create:

- Managed node group.
- Node IAM role.
- Kubernetes workloads.
- EKS add-ons.
- `kubectl` kubeconfig.
- Explicit access entries for additional users or roles.

Those are separate subtasks.

## Validation Result

The real backend-backed plan succeeded:

```text
Plan: 10 to add, 0 to change, 0 to destroy.
```

The EKS-specific planned resources are:

```text
module.eks_cluster.aws_iam_role.cluster
module.eks_cluster.aws_iam_role_policy_attachment.cluster_policy
module.eks_cluster.aws_eks_cluster.this
```

The plan also includes the VPC and six subnets because those previous resources have been planned but not applied yet.

Apply is intentionally deferred for this subtask.

Reason:

- EKS control plane creates ongoing AWS cost after apply.
- A control plane without node groups cannot run CPEmon workloads yet.
- kubeconfig and `kubectl` validation belong to later subtasks.
- Creating the cluster together with node group and access validation gives a cleaner demo and cleanup path.

For this task, the acceptance standard is module completeness plus successful `terraform validate` and `terraform plan`.

## Apply Permission Requirements

Planning the cluster module succeeded, but apply will require additional permissions in the `CPEmonTerraformBootstrap` permission set.

Add these statements to the permission set inline policy.

Cluster role management:

```json
{
  "Sid": "ManageCpemonDevEksClusterRole",
  "Effect": "Allow",
  "Action": [
    "iam:CreateRole",
    "iam:TagRole",
    "iam:GetRole",
    "iam:ListRolePolicies",
    "iam:GetRolePolicy",
    "iam:ListAttachedRolePolicies",
    "iam:ListInstanceProfilesForRole",
    "iam:DetachRolePolicy",
    "iam:DeleteRole"
  ],
  "Resource": "arn:aws:iam::701573843911:role/cpemon-dev-eks-cluster-role"
}
```

Attach only the required AWS managed policy:

```json
{
  "Sid": "AttachOnlyAmazonEksClusterPolicy",
  "Effect": "Allow",
  "Action": [
    "iam:AttachRolePolicy"
  ],
  "Resource": "arn:aws:iam::701573843911:role/cpemon-dev-eks-cluster-role",
  "Condition": {
    "ArnEquals": {
      "iam:PolicyARN": "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    }
  }
}
```

Allow Terraform to pass the cluster role to EKS:

```json
{
  "Sid": "PassCpemonDevEksClusterRoleToEks",
  "Effect": "Allow",
  "Action": [
    "iam:PassRole"
  ],
  "Resource": "arn:aws:iam::701573843911:role/cpemon-dev-eks-cluster-role",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "eks.amazonaws.com"
    }
  }
}
```

Manage the dev EKS cluster:

```json
{
  "Sid": "ManageCpemonDevEksCluster",
  "Effect": "Allow",
  "Action": [
    "eks:CreateCluster",
    "eks:DescribeCluster",
    "eks:TagResource",
    "eks:UntagResource",
    "eks:DeleteCluster",
    "eks:ListTagsForResource"
  ],
  "Resource": "arn:aws:eks:eu-north-1:701573843911:cluster/cpemon-dev"
}
```

If cluster creation fails because the EKS service-linked role does not exist yet, add this narrowly scoped permission:

```json
{
  "Sid": "CreateEksServiceLinkedRoleIfMissing",
  "Effect": "Allow",
  "Action": [
    "iam:CreateServiceLinkedRole"
  ],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "iam:AWSServiceName": "eks.amazonaws.com"
    }
  }
}
```

Keep permissions as narrow as possible and expand only when a real Terraform error proves it is needed.

## Interview Explanation

After building the VPC and subnet foundation, I added an EKS cluster module for the managed Kubernetes control plane. The module creates the EKS cluster IAM role, attaches `AmazonEKSClusterPolicy`, and creates the EKS cluster using the private subnets. I enabled public endpoint access for the dev phase and used EKS API authentication mode so later access management can use EKS access entries instead of relying only on the legacy `aws-auth` ConfigMap.
