# Argo CD Prune and Self-Heal Guardrails

This runbook documents the Story 11 prune and self-heal decision.

## Decision

For the current dev GitOps boundary:

```text
prune:     disabled
self-heal: disabled
```

The decision is recorded on each Application:

```yaml
annotations:
  cpemon.io/sync-prune: "disabled"
  cpemon.io/sync-self-heal: "disabled"
```

No current Application enables:

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Why Prune Needs Care

Prune deletes live resources that are no longer in Git.

That can be correct when ownership is clean, but dangerous when:

* CRDs and custom resources have ordering dependencies
* multiple Applications share namespaces or CRDs
* PVCs or stateful resources are involved
* a chart rename changes resource names
* a manifest path is temporarily empty or wrong
* Git history is rewritten or a bad commit removes resources

For CPEmon, Kafka, monitoring, ESO, Kyverno, and NetworkPolicy all deserve staged
validation before automatic deletion is allowed.

## Why Self-Heal Needs Care

Self-heal automatically reverts live drift back to Git.

That is useful when Git is unquestionably the source of truth, but risky during
learning and incident response:

* an operator may temporarily scale or patch a workload during debugging
* a controller may add runtime fields or generated settings
* NetworkPolicy changes can lock out expected traffic
* ESO and monitoring controllers reconcile their own dependent objects
* Kyverno owns admission webhooks and policy CRDs that should not be pruned by accident

The current approach is to inspect drift first, then sync deliberately.

## Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-prune-self-heal-guardrails.ps1
```

The script confirms:

* every dev Application records prune disabled
* every dev Application records self-heal disabled
* no Application enables `prune: true`
* no Application enables `selfHeal: true`

## Live Inspection

With Argo CD:

```powershell
argocd app get cpemon-dev
argocd app diff cpemon-dev
```

With kubectl:

```powershell
kubectl get application cpemon-dev -n argocd -o yaml
```

## When to Revisit

Prune and self-heal can be considered after:

* resource ownership is split cleanly by Application
* CRD/controller ordering is stable
* stateful resource deletion behavior is documented
* rollback and restore procedures are tested
* Argo CD RBAC limits who can change sync policies
* a non-production environment proves the behavior

## Interview Framing

Automating reconciliation is powerful, but deletion is the sharp edge. A good
GitOps answer explains not just how to enable prune and self-heal, but why you
wait until ownership, ordering, and rollback are understood.
