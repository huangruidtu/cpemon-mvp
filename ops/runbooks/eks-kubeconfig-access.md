# EKS Kubeconfig and kubectl Access Runbook

## Purpose

Use this runbook after the CPEmon dev EKS cluster has been applied.

It explains how to generate kubeconfig and verify that `kubectl` can reach the `cpemon-dev` cluster.

## Preconditions

The following Terraform resources must already exist in AWS:

- VPC and subnets.
- EKS cluster `cpemon-dev`.
- Managed node group `cpemon-dev-ng-main`.
- EKS access entry for the operator IAM Identity Center role.

The following local tools must be installed:

- AWS CLI v2.
- `kubectl`.
- Valid AWS SSO session for profile `cpemon-terraform`.

Current local check on this workstation:

- AWS CLI is installed.
- `kubectl` is not currently available in `PATH`.

Install `kubectl` before running the live `-WriteKubeconfig` validation.

Refresh SSO if needed:

```powershell
aws sso login --profile cpemon-terraform
```

## Safe Preview

Preview the kubeconfig that AWS CLI would generate without writing to your local kubeconfig file:

```powershell
.\scripts\eks-kubeconfig-check.ps1
```

If Windows blocks script execution, run it with a process-scoped bypass:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\eks-kubeconfig-check.ps1
```

The script runs:

- `aws sts get-caller-identity`
- `aws eks describe-cluster`
- `aws eks update-kubeconfig --dry-run`

If the cluster does not exist yet, this fails safely before changing local kubeconfig.

## Generate kubeconfig

After the cluster is active, write the kubeconfig context:

```powershell
.\scripts\eks-kubeconfig-check.ps1 -WriteKubeconfig
```

If Windows blocks script execution:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\eks-kubeconfig-check.ps1 -WriteKubeconfig
```

The script writes a context alias:

```text
cpemon-dev
```

The equivalent raw AWS CLI command is:

```powershell
aws eks update-kubeconfig `
  --region eu-north-1 `
  --name cpemon-dev `
  --profile cpemon-terraform `
  --alias cpemon-dev
```

## Verify access

The script validates:

```powershell
kubectl config current-context
kubectl cluster-info
kubectl get namespaces
kubectl get nodes -o wide
```

Expected results:

- Current context is `cpemon-dev`.
- `kubectl cluster-info` reaches the Kubernetes API server.
- `kubectl get namespaces` returns Kubernetes namespaces.
- `kubectl get nodes -o wide` returns at least one Ready worker node after the node group has joined.

## Troubleshooting

### Cluster not found

Cause:

- Terraform apply has not created the EKS cluster yet.
- Wrong AWS region or profile.

Check:

```powershell
aws eks describe-cluster --region eu-north-1 --name cpemon-dev --profile cpemon-terraform
```

### Unauthorized

Cause:

- The AWS profile is not assuming the IAM principal configured in the EKS access entry.
- The EKS access entry or policy association was not applied.

Check:

```powershell
aws sts get-caller-identity --profile cpemon-terraform
```

Compare the role name with `eks_access_entries.cpemon_terraform_admin.principal_arn` in Terraform.

### Nodes are missing

Cause:

- Cluster API access works, but the managed node group has not joined yet.
- Node IAM role or VPC CNI permissions are incomplete.
- Private subnets do not have the required routing for node bootstrap.

Check:

```powershell
kubectl get nodes -o wide
aws eks describe-nodegroup --region eu-north-1 --cluster-name cpemon-dev --nodegroup-name cpemon-dev-ng-main --profile cpemon-terraform
```

### kubectl Version Warning

AWS recommends using a `kubectl` client within one minor version of the EKS Kubernetes control plane.

Check local client:

```powershell
kubectl version --client
```

Check cluster version:

```powershell
aws eks describe-cluster --region eu-north-1 --name cpemon-dev --profile cpemon-terraform --query "cluster.version" --output text
```
