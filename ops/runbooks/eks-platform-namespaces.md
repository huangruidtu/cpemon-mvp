# EKS Platform Namespaces Runbook

## Purpose

Use this runbook to apply and validate the CPEmon EKS platform namespaces.

This runbook belongs to `CCPU-46`.

## Preconditions

The following must be true before live validation:

- EKS cluster exists.
- kubeconfig points to the intended cluster.
- `kubectl` is installed and available in `PATH`.
- The current AWS identity has EKS/Kubernetes access.

Current project note:

```text
The EKS cluster has not been applied yet, so this runbook is prepared for the post-apply validation window.
```

## Apply

From the repository root:

```powershell
make ns
```

Direct command:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
```

## Validate

```powershell
make ns-check
```

Direct commands:

```powershell
kubectl get ns cpemon platform monitoring argocd kafka security cost backup ingress-nginx
kubectl get ns -L cpemon.io/layer,cpemon.io/managed-by
```

## Expected Namespaces

```text
cpemon
platform
monitoring
argocd
kafka
security
cost
backup
ingress-nginx
```

## Troubleshooting

If `kubectl` cannot connect:

```powershell
kubectl config current-context
kubectl cluster-info
```

If AWS authentication may be wrong:

```powershell
aws sts get-caller-identity --profile cpemon-terraform
```

If the cluster does not exist yet, stop here. Do not spend time debugging namespace YAML before the control plane exists.

If only some namespaces are missing, re-apply the manifest:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
kubectl get ns
```

## Incident Note

Namespace creation is usually not the root cause of a failing workload, but missing namespaces produce very clear symptoms:

```text
Error from server (NotFound): namespaces "cpemon" not found
```

Fix the namespace first, then re-apply the workload manifest.
