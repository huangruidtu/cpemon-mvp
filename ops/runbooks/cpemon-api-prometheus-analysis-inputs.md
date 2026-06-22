# CPEmon API Prometheus Analysis Inputs

Jira: CCPU-197

This runbook validates the metric assumptions behind the `cpemon-api` Argo
Rollouts AnalysisTemplates.

An AnalysisTemplate is only useful when the metric source is trustworthy. The
Rollout can render correctly, but a bad query, missing metric, or high-cardinality
label choice can still make promotion decisions unsafe.

## Metrics Contract

The canary analysis depends on these CPEmon API metrics:

| Metric | Type | Labels | Analysis Use |
| --- | --- | --- | --- |
| `cpemon_api_http_requests_total` | counter | `method`, `route`, `code` | 5xx ratio |
| `cpemon_api_http_request_duration_seconds_bucket` | histogram bucket | `method`, `route`, `code`, `le` | p95 latency |

Label rules:

* `route` must use Gin route templates, not raw URL paths.
* `code` must be the HTTP status code family source for 5xx analysis.
* `method`, `route`, `code`, and `le` are acceptable cardinality for this
  learning environment.
* Do not add device serial numbers, customer IDs, raw route parameters, request
  IDs, or payload fields to canary analysis metrics.

## Offline Validation

Offline validation can prove:

```text
Helm values contain the expected metric names.
AnalysisTemplates render the expected Prometheus queries.
Rollout steps reference the rendered AnalysisTemplates.
Knowledge and interview notes document the live validation boundary.
```

Offline validation cannot prove:

```text
Prometheus is reachable from the Argo Rollouts controller.
Prometheus has scraped fresh cpemon-api samples.
The query returns enough live data during a real canary window.
```

Use:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-prometheus-analysis-inputs.ps1
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

## Live Prometheus Checks

Run these only when a dev cluster and Prometheus instance are reachable.

Port-forward Prometheus:

```powershell
kubectl port-forward svc/kps-kube-prometheus-stack-prometheus -n monitoring 9090:9090
```

Confirm the request counter exists:

```promql
sum(rate(cpemon_api_http_requests_total[2m]))
```

Confirm 5xx ratio query shape:

```promql
sum(rate(cpemon_api_http_requests_total{code=~"5.."}[2m]))
/
clamp_min(sum(rate(cpemon_api_http_requests_total[2m])), 1)
```

Confirm p95 latency query shape:

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(cpemon_api_http_request_duration_seconds_bucket[2m])
  )
)
```

Confirm label cardinality:

```promql
count by (method, route, code) (cpemon_api_http_requests_total)
count by (method, route, code, le) (cpemon_api_http_request_duration_seconds_bucket)
```

Expected results:

```text
Queries return numeric values, not empty vectors.
Route labels look like templates, for example /api/v1/devices/:id/status.
No raw device serial number, customer ID, or request ID appears in labels.
5xx ratio and p95 latency values are understandable before rollout gates use them.
```

## Interview Framing

A strong answer is:

> Before trusting canary analysis, I validate the metrics contract. I check that
> `cpemon-api` emits request counters and latency histograms with bounded labels,
> that the PromQL queries return numeric values, and that offline Helm rendering
> matches the live metric names. Otherwise an AnalysisTemplate can look correct
> but still make a bad promote or abort decision.

