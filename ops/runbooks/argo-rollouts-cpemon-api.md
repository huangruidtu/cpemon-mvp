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

## CCPU-119: Manual Promote and Abort

Manual promotion is an operator decision to continue after inspecting rollout
status and evidence.

Inspect before promotion:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon
kubectl get analysisrun -n cpemon
kubectl get endpoints cpemon-api-stable cpemon-api-canary -n cpemon
```

Promote to the next step:

```powershell
kubectl argo rollouts promote cpemon-api -n cpemon
kubectl argo rollouts get rollout cpemon-api -n cpemon --watch
```

Promote through all remaining pauses only for a controlled demo:

```powershell
kubectl argo rollouts promote cpemon-api -n cpemon --full
```

Use `--full` carefully. It skips the remaining manual pause decision points.
For production-style operation, prefer step-by-step promotion after reviewing
metrics, logs, traces, endpoints, and AnalysisRuns.

Abort the canary:

```powershell
kubectl argo rollouts abort cpemon-api -n cpemon
kubectl argo rollouts get rollout cpemon-api -n cpemon --watch
```

After abort:

```powershell
kubectl get rs,pods,svc,endpoints,analysisrun -n cpemon -l app=cpemon-api
kubectl describe rollout cpemon-api -n cpemon
```

## Promote Decision

Promote when:

```text
Pods are ready.
AnalysisRuns passed.
5xx ratio is below the threshold.
p95 latency is below the threshold.
Stable and canary endpoints are understandable.
No new error pattern appears in logs or traces.
```

Do not promote when:

```text
AnalysisRuns failed or are inconclusive.
Pods are crash-looping or not ready.
The canary Service has no endpoints.
5xx or p95 analysis is failing.
The operator cannot explain the current rollout state.
```

## Abort Decision

Abort when:

```text
The canary is causing user-visible failures.
The canary fails 5xx or p95 analysis.
The new ReplicaSet cannot become ready.
The operator needs to stop exposure before investigating.
```

Abort is not the same as deleting the Rollout. Abort stops progression and
keeps the stable path available while the canary is investigated.

## Expected Demo Behavior

Manual promote:

```text
20% pause -> promote -> analysis -> 50% pause -> promote -> analysis -> 100%
```

Manual abort:

```text
canary exposure -> abort -> rollout stops progressing -> stable path remains
```

The most important demo habit is to show status before and after each command.

## CCPU-192: Healthy Canary Demo Scenario

The healthy canary scenario is documented in:

```text
ops/demos/argo-rollouts/cpemon-api-healthy-canary.md
```

Use it when the canary image is known-good and the goal is to show a successful
progressive delivery path.

`CCPU-124` uses this scenario as the successful canary acceptance path. The most
important operator habit is the promotion evidence checklist: before promoting
from 20% to 50% or from 50% to 100%, verify Rollout phase, ReplicaSet readiness,
stable/canary endpoints, successful AnalysisRuns, 5xx threshold, p95 threshold,
and logs/traces.

The interview phrasing is:

```text
I did not promote because the command was available. I promoted because the
canary evidence was healthy at each gate.
```

Expected healthy path:

```text
stable version serves traffic
20% canary -> pause -> successful 5xx and p95 analysis
50% canary -> pause -> successful 5xx and p95 analysis
100% traffic -> Healthy
```

Operator checkpoints:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon --watch
kubectl get analysisrun -n cpemon
kubectl describe analysisrun -n cpemon
kubectl get endpoints cpemon-api-stable cpemon-api-canary -n cpemon
```

Promote one pause at a time after evidence is healthy:

```powershell
kubectl argo rollouts promote cpemon-api -n cpemon
```

The scenario is safe for dev because it uses the existing rollout gates,
explicit operator checkpoints, and documented stop conditions before promotion.

Scripted successful demo:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/demo-cpemon-api-successful-rollout.ps1
powershell -ExecutionPolicy Bypass -File scripts/demo-cpemon-api-successful-rollout.ps1 -Execute
```

The first command is the default safe dry-run. The second command is for a
connected dev cluster only.

## CCPU-193: Failed Canary Demo Scenario

The failed canary scenario is documented in:

```text
ops/demos/argo-rollouts/cpemon-api-failed-canary.md
```

Use it when the canary image or configuration intentionally creates a controlled
5xx, latency, readiness, or endpoint failure in a dev environment.

Expected failed path:

```text
stable version serves traffic
20% canary -> pause -> failed 5xx or p95 analysis
rollout becomes Degraded or operator aborts
stable path remains available
```

Failure investigation commands:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon --watch
kubectl get analysisrun -n cpemon
kubectl describe analysisrun -n cpemon
kubectl get rs,pods,svc,endpoints -n cpemon -l app=cpemon-api
kubectl describe rollout cpemon-api -n cpemon
```

Abort the unsafe canary:

```powershell
kubectl argo rollouts abort cpemon-api -n cpemon
```

The operator should be able to explain why the rollout stopped before deciding
whether to retry, rollback, or fix forward.

Scripted failed demo:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/demo-cpemon-api-failed-rollout.ps1
powershell -ExecutionPolicy Bypass -File scripts/demo-cpemon-api-failed-rollout.ps1 -Execute
```

The first command is the default safe dry-run. The second command is for an
isolated dev cluster only.

## CCPU-196: Rollback and Incident Response

Use abort when the in-flight canary is unsafe and should stop progressing:

```powershell
kubectl argo rollouts abort cpemon-api -n cpemon
kubectl argo rollouts get rollout cpemon-api -n cpemon --watch
kubectl get endpoints cpemon-api-stable cpemon-api-canary -n cpemon
```

Use rollback when Git desired state should return to the previous known-good
version:

```powershell
git revert <bad-release-commit>
git push
argocd app sync cpemon
kubectl argo rollouts get rollout cpemon-api -n cpemon --watch
```

Incident response checklist:

```text
1. Freeze promotion.
2. Capture rollout status, ReplicaSets, pods, services, endpoints, and AnalysisRuns.
3. Decide whether to abort immediately based on user impact.
4. Preserve the failed AnalysisRun evidence for the incident notes.
5. Revert desired state in Git if the release artifact is wrong.
6. Verify stable endpoints and Healthy rollout status after recovery.
7. Document the failed signal and follow-up action.
```

ADR:

```text
ADR/cloud-platform-upgrade-argo-rollouts-canary-deployment.md
```

## Interview Framing

A strong answer is:

> I do not decide rollout health from one command alone. I start with
> `kubectl argo rollouts get rollout`, then inspect phase, step index, traffic
> weight, ReplicaSets, services, endpoints, and AnalysisRuns. If the rollout is
> paused, I treat that as a decision point. If it is degraded or aborted, I do
> not promote blindly.
