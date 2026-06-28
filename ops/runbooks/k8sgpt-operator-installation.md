# K8sGPT Operator Installation Runbook

## Purpose

Install K8sGPT as a GitOps-managed optional platform addon.

## GitOps Application

```text
Application:   k8sgpt-dev
Namespace:     argocd
Chart repo:    https://charts.k8sgpt.ai/
Chart:         k8sgpt-operator
Values file:   k8s/addons/k8sgpt/values.yaml
Destination:   k8sgpt-operator-system
```

## Manual Sync

The first sync should be manual:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
kubectl apply -f k8s/gitops/dev/applications/k8sgpt-dev.yaml
argocd app sync k8sgpt-dev
argocd app wait k8sgpt-dev --health --sync
```

## Health Checks

```powershell
kubectl get pods -n k8sgpt-operator-system
kubectl get crd | Select-String k8sgpt
kubectl get svc -n k8sgpt-operator-system
```

## Rollback

Because sync is manual and prune is disabled at introduction, rollback is a
controlled Argo CD action:

```powershell
argocd app history k8sgpt-dev
argocd app rollback k8sgpt-dev <revision>
```
