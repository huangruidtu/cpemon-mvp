# ADR: Platform Governance, Cost Visibility, and Basic Autoscaling

## Status

Accepted

## Context

The CPEmon platform migration now includes:

* GitOps-managed application delivery
* Argo Rollouts canary deployment
* Prometheus-based observability
* policy-as-code governance
* namespace-level cost visibility
* a first autoscaling path for `cpemon-api`

Story 20 adds the platform-control layer that keeps the cluster operable as the
application grows. The goal is not to build a large enterprise platform in one
step. The goal is to add small, explainable controls that match the project
stage.

## Decision

Adopt a minimal platform governance, cost, and autoscaling baseline:

```text
Governance:   Kyverno baseline policies
Cost:         OpenCost with existing kube-prometheus-stack Prometheus
Autoscaling:  HPA for cpemon-api CPU scaling
Deferred:     KEDA until event-driven scaling is required
```

## Governance Decision

Use Kyverno for Kubernetes-native policy-as-code.

The first policies focus on:

* required CPU and memory requests/limits
* disallowing `latest` image tags
* required ownership labels
* non-root container execution

These controls catch common platform hygiene issues before they become runtime
incidents or cost surprises.

## Cost Decision

Use OpenCost for visibility first.

OpenCost reuses the existing kube-prometheus-stack Prometheus endpoint rather
than adding another metrics store. The first operational view is namespace-level
allocation across `cpemon`, `kafka`, `monitoring`, `argocd`, `kyverno`, and
`opencost`.

This is visibility, not chargeback. Chargeback would need pricing validation,
ownership mapping, finance process, and review cadence.

## Autoscaling Decision

Use HPA first for `cpemon-api`.

The first scaling signal is CPU utilization. HPA is Kubernetes-native and
requires only metrics-server plus CPU requests. The Helm chart renders the HPA
against either Deployment or Argo Rollouts Rollout, depending on the environment
configuration.

Defer KEDA until Kafka lag, queue depth, or external metrics become primary
scaling signals.

## Consequences

Positive:

* Small platform surface area.
* Clear GitOps ownership for add-ons and policies.
* Cost visibility begins before cost optimization.
* Autoscaling is introduced without another controller.
* Each decision can be explained in an interview with concrete tradeoffs.

Tradeoffs:

* Kyverno policies start in a limited baseline and need expansion over time.
* OpenCost data needs calibration before finance-grade chargeback.
* HPA is not enough for Kafka lag-based worker scaling.
* KEDA remains future work.

## Validation

Local validation is script-driven:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-platform-governance-boundary.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-cost-investigation.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-hpa.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-keda-step2-decision.ps1
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
go test ./...
```

Live validation requires a dev cluster and should not be claimed unless it has
actually been run.

## Interview Answer

```text
I added a small platform-control layer: Kyverno for policy guardrails, OpenCost
for cost visibility, and HPA for basic cpemon-api autoscaling. I deliberately
kept the first version conservative. OpenCost starts as visibility rather than
chargeback, and KEDA is deferred until Kafka lag or queue depth becomes the
right scaling signal.
```
