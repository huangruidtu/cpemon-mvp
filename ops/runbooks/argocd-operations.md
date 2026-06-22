# Argo CD Operations Runbook

This is the long-lived operations runbook for CPEmon Argo CD GitOps
deployment.

## Scope

This runbook covers the dev GitOps boundary created in Story 11:

* Argo CD installed in namespace `argocd`
* AppProject `cpemon`
* dev Applications under `k8s/gitops/dev/applications`
* CPEmon Helm chart deployment
* Kafka, monitoring, External Secrets, Kyverno, OpenCost, and policy/security add-ons

It assumes Argo CD is already installed and kubeconfig points to the target
cluster.

## Application Inventory

| Application | Purpose | Source | Destination |
| --- | --- | --- | --- |
| `cpemon-dev` | CPEmon app chart | `deploy/helm/cpemon` | `cpemon` |
| `kafka-dev` | Kafka platform | Bitnami Kafka chart plus CPEmon values | `kafka` |
| `monitoring-dev` | kube-prometheus-stack | Prometheus community chart plus CPEmon values | `monitoring` |
| `external-secrets-dev` | External Secrets Operator | External Secrets chart plus CPEmon values | `external-secrets` |
| `policy-security-dev` | NetworkPolicy baseline | `k8s/netpol/baseline` | `cpemon` |
| `kyverno-dev` | Kubernetes policy engine | Kyverno chart plus CPEmon values | `kyverno` |
| `kyverno-policies-dev` | Kyverno policy package | `k8s/policies/kyverno` | `kyverno` |
| `opencost-dev` | Cost visibility | OpenCost chart plus CPEmon values | `opencost` |

## Standard Inspection

```powershell
kubectl get applications -n argocd
kubectl get appprojects -n argocd
argocd app list
argocd app get cpemon-dev
argocd app diff cpemon-dev
```

If the Argo CD CLI is not installed, use Kubernetes CRD inspection:

```powershell
kubectl get application cpemon-dev -n argocd -o yaml
kubectl describe application cpemon-dev -n argocd
```

## Sync Order

For a clean dev environment, use this order:

1. `external-secrets-dev`
2. `kafka-dev`
3. `monitoring-dev`
4. `kyverno-dev`
5. `kyverno-policies-dev`
6. `opencost-dev`
7. `policy-security-dev`
8. `cpemon-dev`

Reason:

* ESO installs secret CRDs and the controller before app secrets need sync.
* Kafka is a platform dependency for producer/consumer workloads.
* Monitoring installs CRDs before CPEmon metrics objects depend on them.
* Kyverno installs the policy engine before Kyverno policies are applied.
* Kyverno policies should be reviewed before CPEmon workloads are synced.
* OpenCost can be synced after monitoring is available so cost metrics can be queried.
* Policy/security should be reviewed before or alongside workload rollout.
* CPEmon workloads are last because they depend on platform services.

## Manual Sync

Manual sync is the current approved policy.

```powershell
argocd app diff cpemon-dev
argocd app sync cpemon-dev
argocd app wait cpemon-dev --sync --health --timeout 300
argocd app get cpemon-dev
```

Do not enable automated sync, prune, or self-heal until the guardrail runbook is
updated and approved.

## OutOfSync Troubleshooting

`OutOfSync` means live cluster state differs from Git desired state.

Check:

```powershell
argocd app diff cpemon-dev
argocd app history cpemon-dev
kubectl describe application cpemon-dev -n argocd
```

Common CPEmon causes:

* a manual kubectl patch changed a managed Deployment or Service
* Git changed Helm values but the Application has not been synced
* Application target revision points to a different commit than expected
* a chart or values path changed
* a CRD-backed resource was skipped or rejected

Resolution:

* if Git is correct, run manual sync
* if live hotfix is correct, turn it into a Git change
* if Git is wrong, revert the Git change and sync again

## Degraded Troubleshooting

`Degraded` means Argo CD applied desired state but runtime health is bad.

Check:

```powershell
kubectl get pods -n cpemon
kubectl describe pod -n cpemon -l app.kubernetes.io/instance=cpemon
kubectl logs -n cpemon deploy/cpemon-api
kubectl logs -n cpemon deploy/acs-ingest
kubectl logs -n cpemon deploy/cpemon-writer
```

Common CPEmon causes:

* bad image tag or image pull failure
* missing `cpemon-db` or `cpemon-acs-hmac` Secret
* Kafka bootstrap service not reachable
* MySQL not reachable or DSN is wrong
* readiness probe fails
* NetworkPolicy blocks a required dependency

Resolution depends on the failing resource. Do not assume another sync fixes a
runtime dependency problem.

## Missing CRD

Symptoms:

```text
no matches for kind "ServiceMonitor"
no matches for kind "ExternalSecret"
resource mapping not found
```

Checks:

```powershell
kubectl get crd | Select-String "servicemonitor|externalsecret|prometheusrule"
argocd app get monitoring-dev
argocd app get external-secrets-dev
```

Resolution:

1. Sync the owning operator Application first.
2. Wait for CRDs and controller Deployments.
3. Sync the dependent Application again.

## Wrong Path Or Source

Symptoms:

```text
app path does not exist
manifest generation error
failed to load target state
```

Checks:

```powershell
kubectl get application cpemon-dev -n argocd -o yaml
Test-Path deploy/helm/cpemon/Chart.yaml
Test-Path deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

Resolution:

* fix `spec.source.path` or `spec.sources[*]`
* verify the values file exists at the referenced path
* verify the chart renders locally before syncing again

## Bad Image Tag

Symptoms:

```text
ImagePullBackOff
ErrImagePull
```

Checks:

```powershell
kubectl get pods -n cpemon
kubectl describe pod -n cpemon <pod-name>
kubectl get deployment -n cpemon cpemon-api -o yaml
```

Resolution:

1. Confirm CI published the intended immutable image tag.
2. Update the Helm values in Git to the correct tag.
3. Sync `cpemon-dev`.

Do not overwrite an old tag in place. Prefer a new immutable tag and a Git
promotion commit.

## Permission Failures

Symptoms:

```text
permission denied
application is not permitted in project
source repo is not permitted
namespace is not permitted
cluster resource is not permitted
```

Checks:

```powershell
kubectl get appproject cpemon -n argocd -o yaml
kubectl describe application cpemon-dev -n argocd
```

Resolution:

* add only the required source repo to the AppProject
* add only the required destination namespace
* add cluster-scoped resources only when an operator chart needs them
* avoid changing the project into a wildcard deployment boundary

## Rollback

Rollback is Git-first:

```powershell
git revert <bad-promotion-commit>
argocd app sync cpemon-dev
argocd app wait cpemon-dev --sync --health --timeout 300
```

For platform add-ons, verify the chart rollback implications before syncing,
especially for CRDs, PVCs, StatefulSets, and operator-owned resources.

## Local Repository Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-runbook-adr-interview.ps1
```

This validates that the long-lived runbook, ADR, knowledge index, and interview
notes cover the expected Story 11 GitOps learning material.
