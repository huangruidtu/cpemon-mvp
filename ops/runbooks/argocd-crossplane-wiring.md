# Argo CD Crossplane Wiring Runbook

This runbook documents how CPEmon wires Crossplane configuration and developer
requests through Argo CD.

## Applications

| Application | Sync wave | Path | Purpose |
| --- | --- | --- | --- |
| `crossplane-dev` | existing controller app | Crossplane Helm chart | Installs the Crossplane control plane. |
| `crossplane-providers-dev` | 21 | `k8s/crossplane` include providers/functions | Installs AWS providers, ProviderConfig, runtime config, and functions. |
| `crossplane-platform-apis-dev` | 22 | `k8s/crossplane/platform-apis` | Installs XRDs and Compositions. |
| `crossplane-claims-dev` | 23 | `k8s/crossplane/claims/dev/cpemon-api` | Syncs developer requests. |

## Why These Boundaries

Provider configuration must not be mixed with developer requests. The provider
layer needs platform ownership and IAM review, while claims belong to
application teams and should be reviewed as application intent.

```text
controller -> providers/functions -> platform APIs -> developer requests
```

## Validation

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-crossplane-wiring.ps1
```

## Live Sync

```powershell
kubectl apply -f k8s/gitops/dev/applications/crossplane-dev.yaml
kubectl apply -f k8s/gitops/dev/applications/crossplane-providers-dev.yaml
argocd app sync crossplane-dev
argocd app sync crossplane-providers-dev
argocd app sync crossplane-platform-apis-dev
argocd app sync crossplane-claims-dev
```

Wait for each layer before syncing the next one.

## Interview Answer

Say:

```text
I separated Crossplane GitOps into controller, provider/function, platform API,
and developer request layers. That gives clear ownership and makes failures
easier to isolate: controller health, provider auth, API schema, then claim
reconciliation.
```
