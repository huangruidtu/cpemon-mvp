# EKS Provisioning with Terraform - Cluster Access

## Why This Subtask Exists

`CCPU-41` configures who can access the EKS Kubernetes API after the cluster exists.

Creating a cluster is not the same thing as being able to run:

```bash
kubectl get nodes
```

EKS has two layers:

- AWS IAM authentication: proves which IAM principal is calling the cluster.
- Kubernetes authorization: decides what that principal can do inside Kubernetes.

This task uses EKS access entries and access policy associations instead of manually editing the legacy `aws-auth` ConfigMap.

## What Gets Created

The implementation lives in:

```text
infra/terraform/modules/eks_cluster_access
```

The dev environment calls it from:

```text
infra/terraform/envs/dev/main.tf
```

The module creates:

- `aws_eks_access_entry`
- `aws_eks_access_policy_association`

The dev access entry grants cluster admin access to the Terraform SSO role:

```text
arn:aws:iam::701573843911:role/aws-reserved/sso.amazonaws.com/eu-north-1/AWSReservedSSO_CPEmonTerraformBootstrap_0241ccdc62503c71
```

This is the IAM role behind the current SSO session:

```text
arn:aws:sts::701573843911:assumed-role/AWSReservedSSO_CPEmonTerraformBootstrap_0241ccdc62503c71/cpemon-terraform
```

Do not use the STS assumed-role ARN in an EKS access entry. EKS access entries expect an IAM principal ARN, such as an IAM role ARN.

## Why Access Entries Instead of aws-auth

Historically, EKS cluster access was managed through the `aws-auth` ConfigMap in Kubernetes.

That model has two problems:

- You need working Kubernetes access before you can safely manage access.
- Access is split between AWS IAM and Kubernetes objects.

EKS access entries move this boundary into the EKS API. Terraform can manage access with AWS provider resources:

```hcl
resource "aws_eks_access_entry" "this" {
  cluster_name  = var.cluster_name
  principal_arn = each.value.principal_arn
  type          = each.value.type
}
```

Then Terraform associates an EKS access policy:

```hcl
resource "aws_eks_access_policy_association" "this" {
  cluster_name  = var.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn
}
```

## Authentication Mode

The cluster module already uses:

```hcl
authentication_mode = "API"
```

That means access is managed through the EKS API, not only through the old `aws-auth` ConfigMap.

For dev, we changed:

```hcl
eks_bootstrap_cluster_creator_admin_permissions = false
```

Reason:

- `bootstrap_cluster_creator_admin_permissions = true` gives implicit admin access to whoever creates the cluster.
- If we also create an explicit access entry for the same IAM principal, apply can fail with a duplicate access entry.
- Explicit access entries are easier to audit and explain in an interview.

This is a Day 0 decision because the cluster has not been applied yet.

## Access Policy

The dev environment uses:

```text
arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy
```

with:

```hcl
access_scope = {
  type = "cluster"
}
```

That grants cluster-wide admin access through EKS access management.

This is acceptable for the first dev/admin path. Later, production-like access should split roles:

- Platform admin: cluster admin.
- Developer: namespace-scoped edit.
- Viewer: read-only view.
- CI/CD deployer: namespace-scoped deployment permissions.

## What You Need To Do

Before real apply, confirm this IAM principal ARN:

```text
arn:aws:iam::701573843911:role/aws-reserved/sso.amazonaws.com/eu-north-1/AWSReservedSSO_CPEmonTerraformBootstrap_0241ccdc62503c71
```

How we derived it:

```bash
aws sts get-caller-identity --profile cpemon-terraform
```

Current result:

```text
arn:aws:sts::701573843911:assumed-role/AWSReservedSSO_CPEmonTerraformBootstrap_0241ccdc62503c71/cpemon-terraform
```

Conversion rule:

- STS assumed role ARN is the temporary session identity.
- IAM role ARN is the stable principal you grant access to.

For IAM Identity Center in `eu-north-1`, the role ARN shape is:

```text
arn:aws:iam::<account-id>:role/aws-reserved/sso.amazonaws.com/eu-north-1/<sso-role-name>
```

If the permission set is deleted and recreated, the suffix can change. Update `terraform.tfvars.example` or your private `terraform.tfvars` before apply.

## Apply-Time Permission Requirements

The Terraform execution role needs EKS access-management permissions:

```json
{
  "Sid": "ManageCpemonDevEksAccessEntries",
  "Effect": "Allow",
  "Action": [
    "eks:CreateAccessEntry",
    "eks:DescribeAccessEntry",
    "eks:UpdateAccessEntry",
    "eks:DeleteAccessEntry",
    "eks:ListAccessEntries",
    "eks:AssociateAccessPolicy",
    "eks:DisassociateAccessPolicy",
    "eks:ListAssociatedAccessPolicies",
    "eks:ListAccessPolicies"
  ],
  "Resource": [
    "arn:aws:eks:eu-north-1:701573843911:cluster/cpemon-dev",
    "arn:aws:eks:eu-north-1:701573843911:access-entry/cpemon-dev/*"
  ]
}
```

For kubeconfig generation, the operator also needs:

```json
{
  "Sid": "DescribeCpemonDevEksClusterForKubeconfig",
  "Effect": "Allow",
  "Action": [
    "eks:DescribeCluster"
  ],
  "Resource": "arn:aws:eks:eu-north-1:701573843911:cluster/cpemon-dev"
}
```

## Kubeconfig Process After Apply

After the cluster and access entry are actually applied, configure local kubeconfig:

```bash
aws eks update-kubeconfig \
  --region eu-north-1 \
  --name cpemon-dev \
  --profile cpemon-terraform \
  --alias cpemon-dev
```

Then verify identity and cluster access:

```bash
aws sts get-caller-identity --profile cpemon-terraform
kubectl config current-context
kubectl get nodes
kubectl get namespaces
```

Expected result after node group is active:

- `kubectl get nodes` shows at least one Ready node.
- `kubectl get namespaces` lists Kubernetes namespaces.

If the cluster exists but nodes are not Ready yet, access can still be valid while node bootstrap is still in progress.

## Validation Result

The backend-backed plan succeeded:

```text
Plan: 17 to add, 0 to change, 0 to destroy.
```

The access-specific planned resources are:

```text
module.eks_cluster_access.aws_eks_access_entry.this["cpemon_terraform_admin"]
module.eks_cluster_access.aws_eks_access_policy_association.this["cpemon_terraform_admin.cluster_admin"]
```

The plan also confirms:

```text
authentication_mode = "API"
bootstrap_cluster_creator_admin_permissions = false
```

No `terraform apply` was run.

## Common Errors

### Unauthorized

Cause:

- The IAM principal in kubeconfig is not covered by an EKS access entry.
- The access entry was created for the IAM role ARN, but the user is using a different AWS profile.

Fix:

- Run `aws sts get-caller-identity --profile cpemon-terraform`.
- Confirm the role maps to the access entry principal ARN.

### ResourceInUseException

Cause:

- You tried to create an access entry for a principal that already has an implicit bootstrap access entry.

Fix:

- Do not create a duplicate access entry.
- For this project, we set `eks_bootstrap_cluster_creator_admin_permissions = false` before first apply and manage the admin principal explicitly.

### AccessDenied During Terraform Apply

Cause:

- The Terraform SSO permission set lacks EKS access-management permissions.

Fix:

- Add the least-privilege permissions listed above.
- Re-run `terraform plan` before apply.

## Interview Explanation

I configured EKS access with access entries instead of editing the legacy `aws-auth` ConfigMap. The cluster uses API authentication mode, and Terraform creates an access entry for the SSO role that operates the platform. I disabled implicit cluster-creator admin access before first apply so access is explicit and auditable. After apply, the operator uses `aws eks update-kubeconfig` and validates access with `kubectl get nodes` and `kubectl get namespaces`.

## Sources

- AWS EKS access entries: <https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html>
- AWS EKS access policy associations: <https://docs.aws.amazon.com/eks/latest/userguide/access-policies.html>
- Terraform `aws_eks_access_entry`: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry>
- Terraform `aws_eks_access_policy_association`: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association>
