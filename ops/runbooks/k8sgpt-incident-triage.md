# Platform Incident Triage with K8sGPT

## Purpose

Use K8sGPT as an early summarization tool during Kubernetes incidents.

## Incident Flow

1. Confirm impact from alerts, dashboards, and user reports.
2. Check Argo CD and rollout status.
3. Run K8sGPT analysis for likely Kubernetes causes.
4. Verify findings with kubectl, logs, events, and metrics.
5. Decide rollback, mitigation, or escalation.

## Commands

```powershell
kubectl get pods -n cpemon
kubectl get events -n cpemon --sort-by=.lastTimestamp
k8sgpt analyze --namespace cpemon --explain
argocd app get cpemon-dev
kubectl argo rollouts get rollout cpemon-api -n cpemon
```

## Evidence To Capture

* Alert name and time
* Affected namespace and workload
* K8sGPT finding
* Kubernetes event or log proof
* Argo CD or rollout state
* Human decision

## Decision Boundary

Incident command remains human-led. K8sGPT can support diagnosis, but rollback
and remediation follow existing operational runbooks.
