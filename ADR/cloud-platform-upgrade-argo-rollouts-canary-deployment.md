# ADR: Argo Rollouts Canary Deployment for CPEmon API

Jira: CCPU-196

## Status

Accepted for the learning cloud-platform upgrade.

## Context

`cpemon-api` is the user-facing read API for CPEmon status. A plain Kubernetes
Deployment can roll out new pods, but it does not express traffic weights,
manual gates, metric analysis, promote/abort decisions, or canary-specific
operator workflows.

The project already uses Helm for application manifests, Argo CD for GitOps,
and Prometheus-style HTTP metrics for operational signals. That makes Argo
Rollouts a good next step because it can keep deployment ownership in Git while
adding progressive delivery behavior to the API release path.

## Decision

Use Argo Rollouts for `cpemon-api` canary deployment.

The CPEmon API Rollout uses:

* Stable and canary Services.
* Weighted canary steps at 20%, 50%, and 100%.
* Pause windows before promotion.
* Prometheus AnalysisTemplates for HTTP 5xx rate and p95 latency.
* Manual promote and abort commands for controlled demos and incidents.
* GitOps ownership through the Helm chart and Argo CD sync flow.

## Alternatives Considered

Plain Kubernetes Deployment:

* Simpler and already familiar.
* Does not model canary traffic, analysis gates, or explicit promote/abort
  workflows.

Argo CD only:

* Good for GitOps sync and drift detection.
* Does not replace progressive delivery logic inside the cluster.

Service mesh traffic shifting:

* Powerful for production traffic policy.
* Too large for the current learning step and not needed to demonstrate the
  canary control loop.

## Consequences

Benefits:

* Bad releases get limited exposure before full promotion.
* Runtime signals decide whether the canary should continue.
* Operators can explain rollout state with concrete evidence.
* Interview material becomes stronger because the project includes both
  happy-path and failure-path release demos.

Trade-offs:

* The cluster needs Argo Rollouts CRDs and controller.
* The team must understand Rollout, AnalysisTemplate, AnalysisRun, promote,
  abort, and rollback behavior.
* Live validation requires a reachable dev cluster and Prometheus data.

## Rollback Behavior

Rollback is Git-first when the release artifact is wrong:

```text
revert the image/config change in Git
let Argo CD sync the previous desired state
watch Argo Rollouts return to a safe version
```

Abort is operator-first when the current canary is unsafe:

```text
inspect rollout and AnalysisRun evidence
abort the unsafe canary
preserve stable traffic
decide retry, rollback, or fix forward
```

The important distinction is that abort stops unsafe progression, while rollback
changes desired state back to a known-good version.

## Validation

Repository checks:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argo-rollouts-final-docs.ps1
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
go test ./...
```

Live checks require a reachable dev cluster:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon
kubectl get analysisrun -n cpemon
kubectl argo rollouts promote cpemon-api -n cpemon
kubectl argo rollouts abort cpemon-api -n cpemon
```

