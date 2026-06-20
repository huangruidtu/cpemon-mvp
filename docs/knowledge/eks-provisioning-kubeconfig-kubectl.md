# EKS Provisioning - kubeconfig and kubectl Access

## Why This Subtask Exists

`CCPU-42` turns cluster access into an operator workflow.

The previous task configured EKS access entries in Terraform. This task answers the next practical question:

```text
After the cluster exists, how do I connect kubectl to it and prove access works?
```

Because the EKS cluster has not been applied yet, this task creates the post-apply runbook and validation script. It does not run a real `kubectl get nodes` against AWS yet.

## What kubeconfig Is

`kubeconfig` is the local configuration file that tells `kubectl`:

- Which cluster endpoint to call.
- Which certificate authority data to trust.
- Which user/auth command to use.
- Which context should combine cluster, user, and namespace defaults.

For EKS, `aws eks update-kubeconfig` writes or updates this file.

AWS documentation explains that EKS uses `aws eks get-token` with `kubectl` for authentication, and the AWS CLI uses the same identity shown by:

```bash
aws sts get-caller-identity
```

That is why the first debugging step is always to check the AWS identity behind the profile.

## What We Added

The runbook is:

```text
ops/runbooks/eks-kubeconfig-access.md
```

The PowerShell helper script is:

```text
scripts/eks-kubeconfig-check.ps1
```

The script is intentionally safe by default. Without `-WriteKubeconfig`, it previews the kubeconfig using:

```powershell
aws eks update-kubeconfig --dry-run
```

To write the local kubeconfig after the cluster exists:

```powershell
.\scripts\eks-kubeconfig-check.ps1 -WriteKubeconfig
```

## Script Flow

The script checks local tools:

```powershell
Require-Command "aws"
Require-Command "kubectl"
```

Then it checks the current AWS identity:

```powershell
aws sts get-caller-identity --profile cpemon-terraform
```

Then it checks whether the EKS cluster exists and is active:

```powershell
aws eks describe-cluster `
  --name cpemon-dev `
  --region eu-north-1 `
  --profile cpemon-terraform
```

If the cluster is not `ACTIVE`, the script stops before touching kubeconfig.

If `-WriteKubeconfig` is passed, it runs:

```powershell
aws eks update-kubeconfig `
  --region eu-north-1 `
  --name cpemon-dev `
  --profile cpemon-terraform `
  --alias cpemon-dev
```

Then it verifies:

```powershell
kubectl config current-context
kubectl cluster-info
kubectl get namespaces
kubectl get nodes -o wide
```

## Why We Do Not Run It Yet

The EKS resources are still plan-only.

Current Terraform plan includes EKS cluster, access entries, and managed node group, but no `terraform apply` has been run. Therefore:

- No EKS API endpoint exists.
- No managed node group exists.
- `aws eks update-kubeconfig` cannot generate a working context yet.
- `kubectl get nodes` has no real cluster to query.

So the correct acceptance standard for this subtask is:

- Script exists.
- Runbook exists.
- Script syntax is valid.
- Local prerequisite status is documented.
- Jira explains that live kubectl validation is deferred until apply.

## Validation Result

Completed now:

```text
PowerShell syntax OK
AWS CLI installed: aws-cli/2.35.8
Script confirms current AWS caller identity.
Script stops safely because EKS cluster cpemon-dev does not exist yet.
```

Current blocker for live kubectl validation:

```text
kubectl is not currently available in PATH on this workstation.
```

Current Windows execution policy blocks direct `.ps1` execution. Use:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\eks-kubeconfig-check.ps1
```

This is expected to be fixed before the real post-apply validation.

## What You Need To Do Later

After we intentionally run Terraform apply, you should run:

```powershell
aws sso login --profile cpemon-terraform
.\scripts\eks-kubeconfig-check.ps1 -WriteKubeconfig
```

Expected successful outcome:

- `kubectl config current-context` returns `cpemon-dev`.
- `kubectl get namespaces` succeeds.
- `kubectl get nodes -o wide` shows at least one Ready node.

## Common Errors

### ResourceNotFoundException

The cluster has not been created or the region/name is wrong.

Fix:

```powershell
aws eks describe-cluster --region eu-north-1 --name cpemon-dev --profile cpemon-terraform
```

### Unauthorized

The AWS profile does not map to an EKS access entry.

Fix:

```powershell
aws sts get-caller-identity --profile cpemon-terraform
```

Then compare the role with the Terraform access entry principal.

### Nodes Not Ready

Kubernetes API access is working, but worker nodes have not joined.

Check:

```powershell
aws eks describe-nodegroup --region eu-north-1 --cluster-name cpemon-dev --nodegroup-name cpemon-dev-ng-main --profile cpemon-terraform
kubectl get nodes -o wide
```

## Interview Explanation

I separated cluster access configuration from kubeconfig generation. Terraform defines who can access the cluster through EKS access entries. The operator workflow then uses `aws eks update-kubeconfig` to write a local kubectl context, and validates access with `kubectl cluster-info`, `kubectl get namespaces`, and `kubectl get nodes`. Since the EKS cluster was not applied yet, I delivered this task as a safe post-apply runbook and script instead of pretending a live kubectl test had passed.

## Sources

- AWS CLI `eks update-kubeconfig`: <https://docs.aws.amazon.com/cli/latest/reference/eks/update-kubeconfig.html>
- AWS EKS kubeconfig guide: <https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html>
- AWS EKS kubectl setup: <https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html>
