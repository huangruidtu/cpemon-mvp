# Argo Rollouts CPEmon API Runbook

This runbook covers the `cpemon-api` canary Rollout.

## Scope

`cpemon-api` is the first CPEmon workload migrated from Deployment to Argo
Rollouts. The current chart renders:

```text
Rollout/cpemon-api
Service/cpemon-api
Service/cpemon-api-stable
Service/cpemon-api-canary
AnalysisTemplate/cpemon-api-http-5xx-rate
AnalysisTemplate/cpemon-api-p95-latency
```

## CCPU-118: Verify Rollout Status

Use the Argo Rollouts plugin for the main status view:

```powershell
$env:Path = "$env:USERPROFILE\bin;$env:Path"
kubectl argo rollouts get rollout cpemon-api -n cpemon
```

Watch live progress:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon --watch
```

Machine-readable checks:

```powershell
kubectl get rollout cpemon-api -n cpemon -o yaml
kubectl get rollout cpemon-api -n cpemon -o jsonpath="{.status.phase}{'\n'}"
kubectl get rollout cpemon-api -n cpemon -o jsonpath="{.status.currentStepIndex}{'\n'}"
```

Inspect related runtime objects:

```powershell
kubectl get rs,pods,svc,endpoints,analysisrun -n cpemon -l app=cpemon-api
kubectl describe rollout cpemon-api -n cpemon
kubectl get analysisrun -n cpemon
kubectl describe analysisrun -n cpemon
```

## What To Look For

Healthy:

```text
Rollout phase is Healthy or completed.
Desired, updated, ready, and available replicas agree.
AnalysisRuns passed.
Stable Service points at the promoted ReplicaSet.
```

Progressing:

```text
Rollout is moving through steps.
currentStepIndex changes over time.
New ReplicaSet pods are becoming ready.
AnalysisRuns are running or pending.
```

Paused:

```text
Rollout is waiting at a pause step.
Traffic weight is held at the configured setWeight.
Operator should inspect metrics, logs, traces, endpoints, and AnalysisRuns.
```

Degraded:

```text
Pods are not ready, AnalysisRuns failed, or the controller reports a failure.
Describe the Rollout, ReplicaSets, pods, and AnalysisRuns before promoting.
```

Aborted:

```text
Rollout was explicitly aborted or failed a gate.
Stable ReplicaSet should continue serving traffic.
Investigate the canary ReplicaSet and failed AnalysisRuns.
```

## Status Decision Tree

```text
kubectl argo rollouts get rollout cpemon-api
        |
        v
Is phase Healthy?
        | yes -> promotion complete
        |
        no
        |
        v
Is rollout paused?
        | yes -> inspect AnalysisRuns, metrics, logs, traces, endpoints
        |
        no
        |
        v
Is phase Progressing?
        | yes -> watch pods, ReplicaSets, currentStepIndex, AnalysisRuns
        |
        no
        |
        v
Is phase Degraded or Aborted?
        | yes -> do not promote; investigate and decide retry or rollback
```

## Repository Validation

Offline checks prove the Git/Helm contract:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-rollout-status-runbook.ps1
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

Live cluster validation requires a reachable Kubernetes API server, Argo
Rollouts CRDs, the controller, Prometheus, and the CPEmon chart synced or
installed.

## Interview Framing

A strong answer is:

> I do not decide rollout health from one command alone. I start with
> `kubectl argo rollouts get rollout`, then inspect phase, step index, traffic
> weight, ReplicaSets, services, endpoints, and AnalysisRuns. If the rollout is
> paused, I treat that as a decision point. If it is degraded or aborted, I do
> not promote blindly.
