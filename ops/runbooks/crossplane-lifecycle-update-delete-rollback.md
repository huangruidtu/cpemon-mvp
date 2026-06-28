# Crossplane Lifecycle, Update, Deletion, and Rollback Runbook

This runbook covers the operational lifecycle for CPEmon Crossplane developer
self-service resources.

## Lifecycle Model

```text
request PR -> Argo CD sync -> Crossplane reconcile -> provider resource -> app consumption
```

The platform must manage four lifecycle phases:

* creation
* update
* deletion
* rollback

## Create

1. Developer opens a PR under `k8s/crossplane/claims/<env>/<app>`.
2. CI runs:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-story.ps1
```

3. Platform reviewer checks policy, owner, cost center, region, and deletion
   behavior.
4. Argo CD syncs `crossplane-claims-dev`.
5. Crossplane reconciles the namespaced request.

Live checks:

```powershell
argocd app get crossplane-claims-dev
kubectl get xcpemonbuckets.platform.cpemon.io -n cpemon
kubectl get xcpemondynamotables.platform.cpemon.io -n cpemon
kubectl get xcpemonecrrepositories.platform.cpemon.io -n cpemon
```

## Update

Safe updates include metadata, approved region, resource class, and selected
resource-specific fields. Risky updates include fields that can force provider
replacement.

Before merging an update:

* inspect the diff
* confirm the affected Composition
* confirm deletion policy
* check whether the provider field is immutable
* document expected impact in the PR

## Deletion Policy

`Delete` means deleting the Crossplane request may delete the composed cloud
resource.

`Orphan` means deleting the Crossplane request should leave the cloud resource
behind for manual ownership review.

Default guidance:

| Environment | Data type | Recommended deletionPolicy |
| --- | --- | --- |
| dev | disposable | `Delete` |
| staging | shared test data | `Orphan` |
| prod | user or business data | `Orphan` |

## Delete

For dev disposable resources:

```powershell
kubectl delete -f k8s/crossplane/claims/dev/cpemon-api/s3-artifacts-bucket.yaml
```

For production-like resources, switch or confirm `deletionPolicy: Orphan`
before deletion, then verify cloud ownership manually.

## Rollback

Preferred rollback is Git revert:

```powershell
git revert <commit>
git push
argocd app sync crossplane-claims-dev
```

If a Composition change caused the issue, revert the Composition commit and
sync `crossplane-platform-apis-dev` before re-syncing claims.

## Failure Modes

| Symptom | Likely cause | First check |
| --- | --- | --- |
| Provider unhealthy | package install or IRSA issue | `kubectl get providers.pkg.crossplane.io` |
| Claim not ready | invalid request or policy denial | `kubectl describe <xr> -n cpemon` |
| Managed resource stuck | AWS/provider API issue | `kubectl describe managed -A` |
| Argo app OutOfSync | GitOps path or ordering issue | `argocd app get <app>` |
| Secret missing | live output strategy not configured | inspect XR and composed resource status |

## Live Validation Boundary

This runbook is operational documentation. Commands that query Argo CD,
Crossplane, Kyverno, or AWS require a live cluster and configured credentials.

## Interview Answer

Say:

```text
I documented Crossplane lifecycle operations separately from the manifests:
creation through PR and Argo CD, updates through reviewed request changes,
deletion through deletionPolicy, and rollback through Git revert. I also called
out failure modes for provider auth, composition errors, stuck managed
resources, and Argo CD sync issues.
```
