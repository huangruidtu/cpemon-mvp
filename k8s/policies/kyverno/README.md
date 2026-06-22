# Kyverno Policy Package

This directory contains CPEmon platform Kyverno policies.

The package is deployed by:

```text
k8s/gitops/dev/applications/kyverno-policies-dev.yaml
```

The Kyverno controller itself is deployed separately by:

```text
k8s/gitops/dev/applications/kyverno-dev.yaml
```

This separation is intentional. The platform can validate the policy engine
first, then review and sync policy behavior as a separate GitOps step.

## Current Policies

| Policy | Purpose |
| --- | --- |
| `baseline/require-container-resources.yaml` | Require CPU and memory requests and limits for CPEmon Pods. |
| `baseline/disallow-latest-image-tag.yaml` | Reject CPEmon Pods that use the mutable `:latest` image tag. |
| `baseline/require-standard-labels.yaml` | Require standard `app.kubernetes.io/*` labels on CPEmon Pods. |
| `baseline/require-non-root-containers.yaml` | Require non-root container settings for CPEmon Pods. |

## Validation

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-resource-policy.ps1
```

Live validation, after Kyverno is installed:

```powershell
kubectl apply -f k8s/policies/kyverno/baseline/require-container-resources.yaml
kubectl get clusterpolicy cpemon-require-container-resources
kubectl describe clusterpolicy cpemon-require-container-resources
```
