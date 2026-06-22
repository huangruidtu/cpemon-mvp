# Platform Governance, Cost Visibility, and Autoscaling Final Checklist

This is the final Story 20 checklist and runbook index.

Use it to rehearse the story, validate local artifacts, and know which live
cluster checks remain manual.

## Story Scope

Story 20 adds a conservative platform-control layer:

```text
Governance:   Kyverno baseline policy-as-code
Cost:         OpenCost namespace and workload cost visibility
Autoscaling:  cpemon-api HPA
Decision:     KEDA deferred to Step 2
```

## Runbook Index

Governance:

* `ops/runbooks/platform-governance-boundary.md`
* `ops/runbooks/argocd-kyverno-installation.md`
* `ops/runbooks/kyverno-resource-policy.md`
* `ops/runbooks/kyverno-image-tag-policy.md`
* `ops/runbooks/kyverno-labels-nonroot-policies.md`
* `ops/runbooks/kyverno-policy-fixtures.md`

Cost visibility:

* `ops/runbooks/argocd-opencost-installation.md`
* `ops/runbooks/opencost-prometheus-integration.md`
* `ops/runbooks/opencost-namespace-cost-visibility.md`
* `ops/runbooks/opencost-cost-investigation.md`

Autoscaling:

* `ops/runbooks/cpemon-api-hpa.md`
* `ops/runbooks/cpemon-api-hpa-validation-load-test.md`
* `ops/runbooks/keda-step2-decision.md`

Decision and interview material:

* `ADR/cloud-platform-upgrade-governance-cost-autoscaling.md`
* `ADR/cloud-platform-upgrade-hpa-first-keda-step2.md`
* `ops/runbooks/platform-governance-cost-autoscaling-interview.md`
* `docs/knowledge/platform-governance-cost-autoscaling.md`
* `docs/knowledge/interview/story-20-platform-governance-cost-autoscaling.md`

## Local Validation

Run targeted checks:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-platform-governance-boundary.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-kyverno-installation.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-resource-policy.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-image-tag-policy.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-labels-nonroot-policies.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-policy-fixtures.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-opencost-installation.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-prometheus-integration.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-namespace-cost-visibility.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-cost-investigation.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-hpa.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-hpa-validation.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-keda-step2-decision.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-platform-governance-cost-autoscaling-docs.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-platform-governance-cost-autoscaling-final.ps1
```

Run chart and Go checks:

```powershell
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
go test ./...
git diff --check
```

## Live Cluster Checks

Run these only when a dev cluster is available.

Kyverno:

```powershell
kubectl get pods -n kyverno
kubectl get cpol
kubectl get policyreport -A
```

OpenCost:

```powershell
kubectl get pods,svc -n opencost
kubectl port-forward -n opencost svc/opencost 9003:9003
Invoke-RestMethod "http://localhost:9003/allocation/compute?window=1h&aggregate=namespace"
```

HPA:

```powershell
kubectl get hpa cpemon-api-hpa -n cpemon
kubectl describe hpa cpemon-api-hpa -n cpemon
kubectl top pods -n cpemon
```

## Interview Rehearsal Checklist

Be ready to answer:

* Why Kyverno and what policies did you start with?
* Why OpenCost and why namespace-level cost first?
* Why is visibility different from chargeback?
* Why HPA first for `cpemon-api`?
* How does HPA target Argo Rollouts Rollout?
* Why defer KEDA?
* What would trigger KEDA Step 2?
* What local checks prove the manifests and docs?
* What live checks require a real dev cluster?
* What did you intentionally leave out of Story 20?

## Final Story Answer

```text
I added a conservative platform-control layer for CPEmon. Kyverno gives us
GitOps-managed guardrails, OpenCost gives cost visibility by namespace and
workload, and HPA gives cpemon-api a basic CPU autoscaling path. I kept KEDA as
Step 2 because the strongest KEDA use case is event-driven scaling, such as
Kafka lag for cpemon-writer. The result is a small but explainable foundation
with clear validation scripts, runbooks, ADRs, and interview notes.
```
