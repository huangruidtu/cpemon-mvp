# OpenCost Namespace Cost Visibility Runbook

This runbook explains how to inspect namespace-level cost visibility with
OpenCost.

## Scope

Story 13 uses OpenCost for visibility first, not production chargeback.

The first namespaces to inspect are:

```text
cpemon
kafka
monitoring
argocd
kyverno
opencost
```

These namespaces represent the application, data streaming, observability,
GitOps, governance, and cost visibility layers of the platform.

## Why Namespace Cost Matters

Namespace cost is the first practical FinOps view for Kubernetes because it
matches how this project separates ownership:

| Namespace | Platform meaning | Useful first question |
| --- | --- | --- |
| `cpemon` | application workloads | What does the business app cost to run? |
| `kafka` | streaming platform | Is the event buffer dominating spend? |
| `monitoring` | observability stack | How expensive is platform telemetry? |
| `argocd` | GitOps control plane | What is the deployment control plane baseline? |
| `kyverno` | governance control plane | What does policy enforcement cost? |
| `opencost` | cost visibility | What is the overhead of cost visibility itself? |

This does not prove chargeback readiness. It gives operators a map of where
cost is coming from.

## Local Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-namespace-cost-visibility.ps1
```

## Live OpenCost API

Port-forward OpenCost:

```powershell
kubectl port-forward -n opencost svc/opencost 9003:9003
```

Query namespace allocation:

```powershell
Invoke-RestMethod "http://localhost:9003/allocation/compute?window=1h&aggregate=namespace"
```

For a longer view:

```powershell
Invoke-RestMethod "http://localhost:9003/allocation/compute?window=24h&aggregate=namespace"
```

## What To Look For

Start with:

* which namespace has the highest cost
* whether cost aligns with expected platform ownership
* whether short windows show spikes from rollout, tests, or failed pods
* whether `monitoring` and `kafka` overhead is expected for the environment
* whether application cost in `cpemon` is visible separately from platform cost

## Prometheus Cross-Check

OpenCost depends on Prometheus. Confirm Prometheus is healthy before trusting
allocation output:

```powershell
kubectl get svc -n monitoring kps-kube-prometheus-stack-prometheus
kubectl port-forward -n monitoring svc/kps-kube-prometheus-stack-prometheus 9090:9090
Invoke-RestMethod "http://localhost:9090/-/ready"
```

## Do Not Overclaim

This runbook does not claim:

* production chargeback
* cloud provider invoice reconciliation
* team budget enforcement
* cost anomaly detection
* rightsizing recommendations

Those require longer data windows, pricing configuration, ownership labels,
organizational policy, and review workflows.

## Interview Framing

The concise answer:

```text
I started cost visibility at the namespace level because namespaces match the
platform ownership boundaries: app, Kafka, monitoring, GitOps, governance, and
OpenCost itself. That gives a clear first FinOps view without overclaiming
production chargeback.
```
