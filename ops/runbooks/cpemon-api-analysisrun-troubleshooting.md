# CPEmon API AnalysisRun Troubleshooting

This runbook explains how to debug `cpemon-api` Argo Rollouts AnalysisRuns that
come from the Prometheus-backed 5xx and p95 AnalysisTemplates.

## Mental Model

```text
AnalysisTemplate = reusable Prometheus query and threshold
AnalysisRun = one runtime execution of that template during a rollout
Rollout = workflow that creates AnalysisRuns at canary gates
```

For CPEmon, the key templates are:

```text
cpemon-api-http-5xx-rate
cpemon-api-p95-latency
```

## First Commands

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon
kubectl get analysisrun -n cpemon
kubectl describe analysisrun -n cpemon
kubectl get analysistemplate -n cpemon
kubectl get endpoints cpemon-api-stable cpemon-api-canary -n cpemon
```

Start with the Rollout phase and current step, then inspect the AnalysisRun
message and metric result.

## Status Meanings

Successful:

```text
The Prometheus query returned a value that satisfied the successCondition.
Promotion can continue if the rest of the evidence is healthy.
```

Failed:

```text
The query returned a value outside the threshold, or the provider returned an
error that exceeded the failure limit.
```

Inconclusive:

```text
The AnalysisRun did not prove success or failure. Treat this as a decision
point, not as permission to promote blindly.
```

No AnalysisRun:

```text
The Rollout may not have reached the analysis step, the Rollout may not contain
analysis wiring, or the Argo Rollouts controller may not be reconciling.
```

## Missing Prometheus Data

If the AnalysisRun shows missing or empty Prometheus data, check:

```powershell
kubectl get servicemonitor -A
kubectl get svc cpemon-api -n cpemon -o yaml
kubectl port-forward -n monitoring svc/kps-kube-prometheus-stack-prometheus 9090:9090
```

Then query:

```promql
cpemon_api_http_requests_total
cpemon_api_http_request_duration_seconds_bucket
```

Common causes:

* `cpemon-api` is not exposing `/metrics`.
* The ServiceMonitor selector does not match the Service labels.
* Prometheus has not scraped fresh samples yet.
* The canary has too little traffic for meaningful data.
* Metric labels changed and the query no longer matches.

## Failed 5xx Analysis

If `cpemon-api-http-5xx-rate` fails, inspect:

```powershell
kubectl logs -n cpemon -l app=cpemon-api --tail=100
kubectl get rs,pods,svc,endpoints -n cpemon -l app=cpemon-api
kubectl describe analysisrun -n cpemon
```

Ask:

```text
Is the failure canary-specific?
Did the 5xx ratio breach the threshold?
Did stable traffic remain healthy?
Should we abort before investigating further?
```

## Failed p95 Analysis

If `cpemon-api-p95-latency` fails, inspect:

```powershell
kubectl top pods -n cpemon
kubectl logs -n cpemon -l app=cpemon-api --tail=100
kubectl describe analysisrun -n cpemon
```

Ask:

```text
Is latency caused by the canary image, database, Kafka, or downstream services?
Is the p95 signal also affecting stable traffic?
Is the canary under-replicated or resource constrained?
```

## False Positives and False Negatives

False positive:

```text
The AnalysisRun fails even though the canary is not actually bad.
```

Typical causes include low traffic, stale metrics, bad thresholds, or a
Prometheus scrape issue.

False negative:

```text
The AnalysisRun passes even though the canary has a real problem.
```

Typical causes include missing labels, a query that does not isolate the right
traffic, too short a window, or a failure mode not covered by 5xx/p95.

## Decision Guide

```text
unsafe user impact -> abort
bad image/config -> revert Git and let Argo CD sync
temporary external issue -> retry only after stable health is confirmed
unclear evidence -> keep stopped and investigate
```

Promotion is only appropriate when runtime evidence is healthy and explainable.

## Interview Framing

```text
I troubleshoot AnalysisRuns by separating manifest, metric, and runtime
questions. First I verify the Rollout created the AnalysisRun. Then I inspect
the Prometheus result and threshold. Finally I compare canary and stable
evidence before deciding abort, retry, fix forward, or Git rollback.
```
