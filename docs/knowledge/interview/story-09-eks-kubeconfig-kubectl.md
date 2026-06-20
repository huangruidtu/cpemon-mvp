# Story 9: EKS Provisioning - kubeconfig and kubectl Access

## Q1: What is kubeconfig?

`kubeconfig` is the local configuration that tells `kubectl` how to connect to a Kubernetes cluster. It contains cluster endpoint information, certificate authority data, users, and contexts.

For EKS, the AWS CLI can create or update this file with `aws eks update-kubeconfig`.

## Q2: What does `aws eks update-kubeconfig` do?

It retrieves EKS cluster connection information and writes a kubectl context into kubeconfig.

For CPEmon dev, the command is:

```powershell
aws eks update-kubeconfig `
  --region eu-north-1 `
  --name cpemon-dev `
  --profile cpemon-terraform `
  --alias cpemon-dev
```

## Q3: Why does AWS identity matter for kubectl?

EKS authentication uses AWS IAM. The kubeconfig generated for EKS calls AWS CLI token generation under the hood, so the identity used by `kubectl` comes from the active AWS credentials.

That is why we check:

```powershell
aws sts get-caller-identity --profile cpemon-terraform
```

## Q4: Why is an EKS access entry still required if kubeconfig exists?

Kubeconfig only tells `kubectl` how to reach the cluster and authenticate.

The EKS access entry decides whether the IAM principal is authorized inside the cluster.

Without the access entry and policy association, kubeconfig can exist but `kubectl` can still receive `Unauthorized`.

## Q5: Why did we make the script dry-run by default?

Because changing kubeconfig changes local operator state. A safe script should preview the generated config first and only write it when the operator passes `-WriteKubeconfig`.

This avoids accidentally switching contexts or overwriting assumptions when the EKS cluster does not exist yet.

## Q6: Why could we not run the real kubectl test in this story?

The EKS cluster has not been applied yet. There is no real EKS API endpoint and no worker node group.

So a real `kubectl get nodes` would fail for the correct reason: the cluster does not exist. The useful deliverable now is the repeatable post-apply process.

## Q7: What commands prove access works after apply?

```powershell
kubectl config current-context
kubectl cluster-info
kubectl get namespaces
kubectl get nodes -o wide
```

`kubectl get namespaces` proves Kubernetes API authorization works. `kubectl get nodes` also proves worker nodes have joined.

## Q8: What does `kubectl get nodes` tell you?

It tells you whether worker nodes are registered with the Kubernetes control plane.

If namespace listing works but nodes are missing or NotReady, access may be fine while node group bootstrap is still failing or incomplete.

## Q9: What is the first thing to check when kubectl says Unauthorized?

Check the AWS identity:

```powershell
aws sts get-caller-identity --profile cpemon-terraform
```

Then verify that this role maps to the EKS access entry configured by Terraform.

## Q10: How would you explain this in an interview?

I treated kubeconfig generation as an operator workflow, not as Terraform-managed state. Terraform controls cluster access through EKS access entries. After apply, the operator runs a scripted `aws eks update-kubeconfig` flow and validates the Kubernetes API with `kubectl`. Since the cluster was not created yet, I delivered a safe post-apply runbook and dry-run script instead of claiming a live cluster validation that could not exist.
