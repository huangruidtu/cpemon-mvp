# Platform Governance, Cost Visibility, and Autoscaling Boundary

Story: `CCPU-144`

This runbook defines the operating boundary for the Story 13 platform work.

## Components

| Component | Installed where | Local install required? | Purpose |
| --- | --- | --- | --- |
| Kyverno | Kubernetes cluster | No | Admission policy and policy reports. |
| OpenCost | Kubernetes cluster | No | Namespace and workload cost visibility. |
| HPA | Kubernetes API resource | No | Basic `cpemon-api` autoscaling. |

Local developer tools:

```text
helm
kubectl
PowerShell
Go
```

Kyverno and OpenCost should be installed into the cluster through Helm/GitOps
manifests. They are not laptop-side tools for this project.

## Step 1 Boundary

This story proves:

```text
baseline policy exists
cost visibility exists
basic API autoscaling exists
```

It does not prove:

```text
complete security hardening
production chargeback
KEDA event-driven autoscaling
custom metric autoscaling
```

## Live Validation Commands

Run these only when connected to the intended dev cluster:

```powershell
kubectl get pods -n kyverno
kubectl get cpol
kubectl get policyreport -A
kubectl get pods -n opencost
kubectl port-forward -n opencost svc/opencost 9090:9090
kubectl get hpa -n cpemon
kubectl describe hpa cpemon-api -n cpemon
```

## Troubleshooting Questions

Kyverno:

```text
Is the policy installed?
Is it Audit or Enforce?
Which namespace does it match?
Does the policy report explain the violation?
```

OpenCost:

```text
Is OpenCost running?
Can it reach Prometheus?
Which namespace or workload is driving cost?
Are requests, limits, PVCs, or node usage responsible?
```

HPA:

```text
Does cpemon-api have resource requests?
Is metrics-server available?
Does the HPA target the correct workload?
Are min/max replicas conservative?
```

## Interview Framing

```text
This story adds the platform guardrails around deployment: policy-as-code with
Kyverno, visibility with OpenCost, and a conservative HPA for cpemon-api. The
point is not maximum sophistication; the point is a safe and explainable first
operations baseline.
```
