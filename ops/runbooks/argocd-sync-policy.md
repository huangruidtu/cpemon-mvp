# Argo CD Sync Policy Runbook

This runbook documents the Story 11 sync policy decision for the dev
Applications.

## Decision

Use manual sync for the current learning environment.

```text
automated sync: disabled
prune:          disabled
self-heal:      disabled
```

Each Application records this decision as metadata:

```yaml
annotations:
  cpemon.io/sync-policy: manual
  cpemon.io/sync-prune: "disabled"
  cpemon.io/sync-self-heal: "disabled"
```

Argo CD treats an Application without `spec.syncPolicy.automated` as manual.
The annotations make that implicit default explicit for review and interview
explanation.

## Applications Covered

```text
k8s/gitops/dev/applications/cpemon-dev.yaml
k8s/gitops/dev/applications/kafka-dev.yaml
k8s/gitops/dev/applications/monitoring-dev.yaml
k8s/gitops/dev/applications/external-secrets-dev.yaml
k8s/gitops/dev/applications/policy-security-dev.yaml
```

## Why Manual First

Manual sync keeps the first GitOps story controlled:

* CPEmon has an image tag promotion boundary.
* Kafka and monitoring are stateful/platform add-ons.
* External Secrets depends on CRDs, IRSA, AWS Secrets Manager, and KMS.
* NetworkPolicy enforcement depends on CNI behavior and real traffic tests.

Automated sync is useful later, but only after each Application has clear
health checks, rollback expectations, and safe prune behavior.

## Manual Sync Commands

With the Argo CD CLI:

```powershell
argocd app sync cpemon-dev
argocd app sync kafka-dev
argocd app sync monitoring-dev
argocd app sync external-secrets-dev
argocd app sync policy-security-dev
```

With kubectl, inspect state:

```powershell
kubectl get application -n argocd
kubectl describe application cpemon-dev -n argocd
```

## Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-sync-policy.ps1
```

The script verifies every dev Application:

* declares `cpemon.io/sync-policy: manual`
* declares prune disabled
* declares self-heal disabled
* does not contain `automated:`

## When Automated Sync Becomes Safer

Automated sync can be considered after:

* image tag promotion is explicit and reviewable
* platform Applications have stable health checks
* CRD/operator ordering is solved
* prune has been tested in a non-production environment
* NetworkPolicy rollout has connectivity tests
* Argo CD RBAC and project boundaries are hardened

## Interview Framing

Argo CD sync is reconciliation from Git to the cluster. It is not a CI build
step. CI creates artifacts and updates desired state; Argo CD applies the
desired state. Manual sync is a deliberate learning-stage safety choice, not a
failure to automate.
