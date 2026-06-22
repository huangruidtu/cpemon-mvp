# Argo CD Drift Detection Validation Runbook

This runbook validates manual drift detection and reconciliation.

## Purpose

Drift detection is one of the main GitOps benefits:

```text
Git desired state != live cluster state
        |
        v
Argo CD marks the Application OutOfSync
        |
        v
operator reviews diff
        |
        v
manual sync reconciles cluster back to Git
```

## Safe Drift Example

Use a harmless annotation drift on a CPEmon Deployment after `cpemon-dev` is
synced:

```powershell
kubectl -n cpemon annotate deployment cpemon-api `
  cpemon.io/manual-drift-test="$(Get-Date -Format o)" `
  --overwrite
```

Alternative safe drift for a lab only:

```powershell
kubectl -n cpemon scale deployment cpemon-api --replicas=1
```

Prefer annotation drift because it does not change capacity.

## Observe Drift

```powershell
argocd app get cpemon-dev
argocd app diff cpemon-dev
kubectl get application cpemon-dev -n argocd -o yaml
```

Expected state:

```text
Sync Status: OutOfSync
Health Status: Healthy or Progressing
```

Health can remain healthy because a metadata annotation drift does not
necessarily break runtime behavior.

## Reconcile Manually

Self-heal is disabled in the current dev boundary, so use manual sync:

```powershell
argocd app sync cpemon-dev
argocd app wait cpemon-dev --sync --health --timeout 300
argocd app get cpemon-dev
```

Expected state:

```text
Sync Status: Synced
Health Status: Healthy
```

## Recovery

If the drift test causes unexpected behavior:

```powershell
kubectl -n cpemon rollout status deployment/cpemon-api
kubectl -n cpemon describe deployment cpemon-api
kubectl -n cpemon rollout restart deployment/cpemon-api
argocd app sync cpemon-dev
```

If a bad Git change was committed, revert Git and let Argo CD reconcile the
reverted desired state:

```powershell
git revert <bad-commit>
argocd app sync cpemon-dev
```

## What This Proves

This proves Argo CD can detect when the live cluster diverges from Git and can
reconcile it back to the declared desired state.

## What This Does Not Prove

It does not prove:

* automated self-heal behavior, because self-heal is disabled
* prune safety
* image promotion correctness
* secret sync correctness
* application functional correctness

## Current Local Boundary

The current local shell has no reachable Kubernetes API. This runbook is
therefore prepared for the live cluster phase. Repository validation checks
that the drift procedure, expected statuses, and recovery steps are documented.
