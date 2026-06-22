# CPEmon API HTTP 5xx AnalysisTemplate Runbook

This runbook documents the `cpemon-api` HTTP 5xx canary gate used by Argo
Rollouts.

## Purpose

The 5xx AnalysisTemplate protects the rollout from promoting a server-side
failure. It answers one release question:

```text
Is the canary returning too many server errors compared with total traffic?
```

The gate is intentionally simple. A canary that creates elevated 5xx responses
should not receive more traffic until an operator investigates or rolls back.

## Rendered Resource

The Helm chart renders:

```text
AnalysisTemplate/cpemon-api-http-5xx-rate
```

The chart values define:

```yaml
rolloutAnalysis:
  templates:
    http5xxRate:
      enabled: true
      name: cpemon-api-http-5xx-rate
      metricName: http-5xx-rate
      interval: 30s
      count: 3
      failureLimit: 1
      successCondition: result[0] < 0.05
```

## PromQL

The analysis uses the CPEmon API RED request counter:

```text
cpemon_api_http_requests_total
```

The query is:

```promql
sum(rate(cpemon_api_http_requests_total{code=~"5.."}[2m]))
/
clamp_min(sum(rate(cpemon_api_http_requests_total[2m])), 1)
```

This calculates:

```text
5xx request rate / total request rate
```

## Threshold

The dev threshold is:

```text
result[0] < 0.05
```

That means the canary passes only when the measured 5xx ratio is below 5%.

For production, this number should be tuned from SLOs and historical baseline
traffic. The important design point is that the chart keeps the threshold
explicit and reviewable instead of hiding it in a script.

## Why clamp_min Is Used

`clamp_min(..., 1)` prevents divide-by-zero behavior when traffic is tiny or no
requests were scraped in the window.

This is a defensive query choice. It keeps the AnalysisRun from failing because
the denominator is empty, while still producing a conservative ratio when there
is real 5xx traffic.

## Label Safety

The query uses bounded labels:

```text
code=~"5.."
```

It does not group by request ID, device serial number, customer ID, raw URL
parameter, or payload value. Canary analysis should use low-cardinality signals
so Prometheus stays reliable during release decisions.

## Offline Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-http5xx-analysis.ps1
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
```

The verifier checks that Helm values, the AnalysisTemplate template, chart
documentation, knowledge notes, interview notes, and this runbook all describe
the same 5xx gate.

## Live Validation

In a dev cluster with Prometheus available, validate the runtime signal before
trusting it for rollout decisions:

```powershell
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090
```

Then query:

```promql
sum(rate(cpemon_api_http_requests_total{code=~"5.."}[2m]))
/
clamp_min(sum(rate(cpemon_api_http_requests_total[2m])), 1)
```

Expected result:

```text
single numeric ratio, normally below 0.05 for a healthy canary
```

If the query returns no data, validate that `cpemon-api` is exposing `/metrics`,
the ServiceMonitor selects the service, and Prometheus has scraped fresh
samples.

## Troubleshooting

If the AnalysisRun fails:

1. Inspect the AnalysisRun result.
2. Check `cpemon-api` logs for server-side errors.
3. Compare stable and canary ReplicaSet health.
4. Inspect endpoint routing for stable and canary Services.
5. Decide whether to abort, retry, fix forward, or roll back through Git.

Commands:

```powershell
kubectl get analysisrun -n cpemon
kubectl describe analysisrun -n cpemon
kubectl argo rollouts get rollout cpemon-api -n cpemon
kubectl logs -n cpemon -l app=cpemon-api --tail=100
```

## Interview Framing

The strong interview answer is:

```text
I used HTTP 5xx rate as the first canary gate because it is the clearest API
reliability signal. The query compares server errors against total traffic,
uses bounded labels, avoids divide-by-zero behavior with clamp_min, and fails
the rollout before a bad canary receives more traffic.
```
