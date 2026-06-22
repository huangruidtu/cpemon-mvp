# CPEmon API Failed Canary Demo Scenario

Jira: CCPU-193

This scenario demonstrates Argo Rollouts stopping a bad `cpemon-api` release
before it reaches full traffic.

The goal is to show the safety story clearly:

```text
stable version keeps serving traffic
bad canary receives limited exposure
runtime signals fail
rollout stops or is aborted
operator investigates before retrying
```

## Preconditions

Use a dev namespace and a reachable Kubernetes cluster with:

* Argo Rollouts controller installed.
* `kubectl argo rollouts` plugin installed.
* CPEmon Helm chart synced or installed.
* Prometheus scraping `cpemon-api` HTTP request metrics.
* A controlled failure trigger, such as a test image that produces artificial
  500 responses or latency above the p95 threshold.

Do not run this scenario against shared production traffic. It is designed for
dev or an isolated demo environment.

## Starting State

Confirm the rollout is healthy before introducing the bad canary:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon
kubectl get endpoints cpemon-api-stable cpemon-api-canary -n cpemon
kubectl get analysisrun -n cpemon
```

Expected observation:

```text
Rollout phase is Healthy.
Stable Service has ready endpoints.
No failed AnalysisRun is currently blocking the rollout.
```

## Trigger a Failed Canary

In GitOps, commit a dev-only image tag or configuration that intentionally
causes one of these failures:

```text
HTTP 5xx rate rises above the configured threshold.
p95 latency rises above the configured threshold.
Canary pods fail readiness.
Canary Service has no ready endpoints.
```

The failure should create a new canary ReplicaSet under the existing Rollout.

## Expected Failed Rollout Path

The expected path is:

```text
20% canary traffic
pause
AnalysisRun evaluates 5xx and p95
AnalysisRun fails or the operator sees unsafe evidence
rollout becomes Degraded or is manually aborted
stable path remains available
```

Watch rollout status:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon --watch
```

Inspect the failed evidence:

```powershell
kubectl get analysisrun -n cpemon
kubectl describe analysisrun -n cpemon
kubectl get rs,pods,svc,endpoints -n cpemon -l app=cpemon-api
kubectl describe rollout cpemon-api -n cpemon
```

Expected failure evidence:

```text
AnalysisRun status is Failed or rollout phase is Degraded.
5xx ratio or p95 latency breached the threshold.
Canary ReplicaSet remains limited in exposure.
Stable Service still has ready endpoints.
The operator does not promote the canary.
```

Abort when the canary is unsafe:

```powershell
kubectl argo rollouts abort cpemon-api -n cpemon
kubectl argo rollouts get rollout cpemon-api -n cpemon --watch
```

## Recovery Check

After aborting or after the rollout degrades, verify:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon
kubectl get endpoints cpemon-api-stable cpemon-api-canary -n cpemon
kubectl get analysisrun -n cpemon
```

Expected final observation:

```text
Bad canary is not promoted to full traffic.
Stable path remains the safe serving path.
Failed AnalysisRun records the reason for the stop.
The next action is fix, retry, or rollback through the normal release process.
```

## Interview Narrative

A concise interview answer:

> I use the failed canary demo to show why progressive delivery matters. The
> canary gets a small amount of traffic, Prometheus analysis detects 5xx or p95
> regression, and Argo Rollouts stops progression. If the evidence is unsafe, I
> abort rather than promote. The key production value is blast-radius reduction:
> the bad version is exposed narrowly while the stable Service remains the safe
> path.

