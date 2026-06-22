# CPEmon API p95 Latency AnalysisTemplate Runbook

This runbook documents the `cpemon-api` p95 latency canary gate used by Argo
Rollouts.

## Purpose

The p95 AnalysisTemplate protects the rollout from promoting a canary that is
slow even when requests still return successful HTTP status codes.

It answers one release question:

```text
Is the canary making the API too slow for the slowest meaningful user cohort?
```

5xx rate catches failed requests. p95 latency catches degraded successful
requests.

## Rendered Resource

The Helm chart renders:

```text
AnalysisTemplate/cpemon-api-p95-latency
```

The chart values define:

```yaml
rolloutAnalysis:
  templates:
    p95Latency:
      enabled: true
      name: cpemon-api-p95-latency
      metricName: p95-latency
      interval: 30s
      count: 3
      failureLimit: 1
      successCondition: result[0] < 0.5
```

## PromQL

The analysis uses the CPEmon API request duration histogram:

```text
cpemon_api_http_request_duration_seconds_bucket
```

The query is:

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(cpemon_api_http_request_duration_seconds_bucket[2m])
  )
)
```

`histogram_quantile(0.95, ...)` estimates the request duration where 95% of
requests are faster than the returned value.

## Threshold

The dev threshold is:

```text
result[0] < 0.5
```

That means the canary passes only when p95 latency is below 0.5 seconds.

For production, this threshold should come from API latency SLOs and historical
baseline behavior. The chart keeps the value explicit so it can be reviewed and
tuned per environment.

## Why sum by (le) Is Required

Prometheus histograms store observations in bucket time series. The `le` label
is the bucket boundary, and `histogram_quantile` needs those bucket boundaries
to calculate a quantile.

The query aggregates with:

```promql
sum by (le) (...)
```

This preserves `le` while removing dimensions that are not required for the
rollout decision.

## Offline Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-p95-analysis.ps1
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
```

The verifier checks that Helm values, the AnalysisTemplate template, chart
documentation, knowledge notes, interview notes, and this runbook all describe
the same p95 latency gate.

## Live Validation

In a dev cluster with Prometheus available, validate the runtime signal before
trusting it for rollout decisions:

```powershell
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090
```

Then query:

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(cpemon_api_http_request_duration_seconds_bucket[2m])
  )
)
```

Expected result:

```text
single numeric latency value in seconds, normally below 0.5 for a healthy dev canary
```

If the query returns no data, validate that `cpemon-api` exposes duration
histogram buckets, the ServiceMonitor selects the service, and Prometheus has
fresh scrape samples.

## Troubleshooting

If the p95 AnalysisRun fails:

1. Check whether errors are also increasing, or whether the problem is only
   latency.
2. Compare stable and canary logs for slow database calls, Kafka calls, or
   downstream service delays.
3. Inspect pod CPU and memory pressure.
4. Check whether canary endpoints are overloaded or under-replicated.
5. Decide whether to abort, retry, fix forward, or roll back through Git.

Commands:

```powershell
kubectl get analysisrun -n cpemon
kubectl describe analysisrun -n cpemon
kubectl argo rollouts get rollout cpemon-api -n cpemon
kubectl top pods -n cpemon
kubectl logs -n cpemon -l app=cpemon-api --tail=100
```

## Interview Framing

The strong interview answer is:

```text
I paired 5xx analysis with p95 latency analysis because a canary can be
functionally correct but too slow. The p95 gate uses Prometheus histogram
buckets, preserves the le label for histogram_quantile, and fails promotion
when the canary exceeds the latency threshold.
```
