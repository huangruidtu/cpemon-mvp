# Argo CD K8sGPT Applications

## Applications

```text
k8sgpt-dev        installs the operator chart
k8sgpt-config-dev applies CPEmon K8sGPT CR, RBAC, and templates
```

## Sync Order

1. `k8sgpt-dev`
2. `k8sgpt-config-dev`

The config application depends on operator CRDs, so it should not be synced
first.

## Guardrails

Both applications start with:

```text
manual sync
prune disabled
self-heal disabled
```

That keeps initial rollout visible and reversible.

## Validation

```powershell
kubectl get applications -n argocd k8sgpt-dev k8sgpt-config-dev
kubectl get pods -n k8sgpt-operator-system
kubectl get k8sgpt -n k8sgpt-operator-system
```
