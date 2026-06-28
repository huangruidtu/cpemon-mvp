# K8sGPT Offline Validation

## Purpose

Validate the repository framework without requiring a live EKS cluster or AI
backend.

## Offline Checks

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-k8sgpt-detective-layer.ps1
```

The script checks:

* Argo CD applications
* Helm values
* K8sGPT CR and Secret template
* RBAC files
* controlled failure demos
* runbooks
* ADR
* knowledge notes
* interview notes
* Makefile target

## Live Boundary

Live validation is intentionally separate:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
kubectl apply -f k8s/gitops/dev/applications/k8sgpt-dev.yaml
kubectl apply -f k8s/gitops/dev/applications/k8sgpt-config-dev.yaml
k8sgpt analyze --namespace cpemon --explain
```

Do live validation only after backend credentials and cluster permissions are
ready.
