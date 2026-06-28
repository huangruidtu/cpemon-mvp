# Argo CD Crossplane Installation Runbook

This runbook validates the `crossplane-dev` Argo CD Application.

## Application Contract

```text
Application:    crossplane-dev
Project:        cpemon
Chart repo:     https://charts.crossplane.io/stable
Chart:          crossplane
Chart version:  2.3.2
Release name:   crossplane
Values source:  https://github.com/huangruidtu/cpemon-mvp.git
Values file:    k8s/addons/crossplane/values.yaml
Destination:    https://kubernetes.default.svc / crossplane-system
Sync policy:    manual
```

Crossplane is installed as platform control-plane infrastructure. This task
installs only the controller layer. AWS Provider packages, ProviderConfig,
XRDs, Compositions, and developer claims are added as later subtasks so each
layer has a clean review boundary.

## Local Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-crossplane-installation.ps1
```

Render the chart locally:

```powershell
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update crossplane-stable
helm template crossplane crossplane-stable/crossplane `
  --version 2.3.2 `
  --namespace crossplane-system `
  --values k8s/addons/crossplane/values.yaml
```

## Apply Through Argo CD

```powershell
kubectl apply -f k8s/base/namespaces.yaml
kubectl apply -f k8s/addons/argocd/projects/cpemon-project.yaml
kubectl apply -f k8s/gitops/dev/applications/crossplane-dev.yaml
argocd app get crossplane-dev
argocd app diff crossplane-dev
argocd app sync crossplane-dev
argocd app wait crossplane-dev --sync --health --timeout 300
```

## Runtime Validation

```powershell
kubectl get pods,svc,deploy -n crossplane-system
kubectl get crd | Select-String crossplane
kubectl get deployment -n crossplane-system
kubectl logs -n crossplane-system deploy/crossplane --tail=100
```

Expected result:

```text
crossplane controller is Running
rbac-manager is Running when installed by the chart
Crossplane CRDs exist
Argo CD reports crossplane-dev Synced and Healthy
```

## Troubleshooting

If Argo CD rejects cluster-scoped resources, check the `cpemon` AppProject
cluster resource whitelist.

If pods are not running, check:

```powershell
kubectl describe pod -n crossplane-system -l app=crossplane
kubectl get events -n crossplane-system --sort-by=.lastTimestamp
```

If the chart render fails locally, confirm Helm can reach:

```text
https://charts.crossplane.io/stable
```

## Interview Framing

The concise answer:

```text
I installed Crossplane through Argo CD as a platform control-plane add-on. I
kept the controller installation separate from provider configuration and
developer claims so each layer has a clear operational boundary and validation
path.
```
