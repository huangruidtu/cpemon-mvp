# CPEmon API Healthy Canary Demo Scenario

Jira: CCPU-192

This scenario demonstrates a good `cpemon-api` release moving through the Argo
Rollouts canary gates and reaching full promotion.

The goal is to show the operational story clearly:

```text
stable version serves traffic
new canary version starts at low exposure
metrics stay healthy
operator promotes at safe gates
new version becomes the stable version
```

## Preconditions

Use a dev namespace and a reachable Kubernetes cluster with:

* Argo Rollouts controller installed.
* `kubectl argo rollouts` plugin installed.
* CPEmon Helm chart synced or installed.
* Prometheus scraping `cpemon-api` HTTP request metrics.
* A known-good canary image tag that keeps health checks, 5xx rate, and p95
  latency within the configured thresholds.

This repo validates the manifest and runbook contract offline. Live traffic
promotion is intentionally left to a dev cluster.

## Starting State

Confirm the currently stable rollout before changing the image:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon
kubectl get rs,pods,svc,endpoints,analysisrun -n cpemon -l app=cpemon-api
kubectl get endpoints cpemon-api-stable cpemon-api-canary -n cpemon
```

Expected observation:

```text
Rollout phase is Healthy.
Stable Service has ready endpoints.
No active failed AnalysisRun is blocking promotion.
```

## Trigger a Healthy Canary

In a GitOps workflow, update the `cpemon-api` image tag in the Helm values used
by the environment, commit the change, and let Argo CD sync it.

For a local Helm-based dev rehearsal, render or apply the chart with the new
image tag:

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

Live apply commands depend on the target dev cluster and release process. The
important boundary is that the image change creates a new ReplicaSet under the
same Rollout resource.

## Expected Rollout Path

The CPEmon API canary steps are:

```text
20% traffic
pause 60s
run cpemon-api-http-5xx-rate and cpemon-api-p95-latency analysis
50% traffic
pause 120s
run cpemon-api-http-5xx-rate and cpemon-api-p95-latency analysis
100% traffic
Healthy
```

Watch the rollout:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon --watch
```

At each pause, inspect the evidence:

```powershell
kubectl get analysisrun -n cpemon
kubectl describe analysisrun -n cpemon
kubectl get endpoints cpemon-api-stable cpemon-api-canary -n cpemon
```

Healthy evidence:

```text
New ReplicaSet pods are Ready.
AnalysisRuns are Successful.
HTTP 5xx rate is below the threshold.
p95 latency is below the threshold.
Stable and canary endpoints are understandable.
No new error pattern appears in logs or traces.
```

Promote one pause at a time:

```powershell
kubectl argo rollouts promote cpemon-api -n cpemon
kubectl argo rollouts get rollout cpemon-api -n cpemon --watch
```

## Completion Check

After the final promotion, verify:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon
kubectl get rollout cpemon-api -n cpemon -o yaml
kubectl get rs,pods,svc,endpoints,analysisrun -n cpemon -l app=cpemon-api
```

Expected final observation:

```text
Rollout phase is Healthy.
The new ReplicaSet is the stable ReplicaSet.
Canary traffic is no longer partially split.
The most recent AnalysisRuns are Successful.
```

## Interview Narrative

A concise interview answer:

> I modeled `cpemon-api` as an Argo Rollouts canary rather than a plain
> Deployment. A healthy release starts with stable traffic, creates a canary
> ReplicaSet, shifts to 20%, pauses, runs 5xx and p95 analysis, then repeats at
> 50%. I only promote after checking pods, services, endpoints, AnalysisRuns,
> logs, traces, and metrics. The demo ends when the Rollout is Healthy and the
> new ReplicaSet has become stable.

