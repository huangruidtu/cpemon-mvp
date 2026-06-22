# CPEmon API Rollout Analysis Wiring Runbook

This runbook documents how the `cpemon-api` Rollout connects Prometheus-backed
AnalysisTemplates to canary progression.

## Purpose

The wiring task turns metric definitions into release gates. The AnalysisTemplates
define what to measure, but the Rollout decides when those checks run.

The release question is:

```text
Did the canary pass both reliability and latency checks before receiving more traffic?
```

## Rendered Relationship

The Helm chart renders:

```text
Rollout/cpemon-api
AnalysisTemplate/cpemon-api-http-5xx-rate
AnalysisTemplate/cpemon-api-p95-latency
```

The Rollout references both templates in its canary steps:

```yaml
- setWeight: 20
- pause:
    duration: 60s
- analysis:
    templates:
      - templateName: cpemon-api-http-5xx-rate
      - templateName: cpemon-api-p95-latency
- setWeight: 50
- pause:
    duration: 120s
- analysis:
    templates:
      - templateName: cpemon-api-http-5xx-rate
      - templateName: cpemon-api-p95-latency
- setWeight: 100
```

## Why Analysis Runs After Pauses

The analysis gates run after the 20% and 50% pause windows.

That order matters:

```text
send limited traffic -> wait for Prometheus scrapes -> evaluate metrics -> decide next exposure
```

If analysis ran immediately after `setWeight`, Prometheus might not have enough
fresh samples to make a reliable decision. The pause gives the canary a short
measurement window.

## Resource Roles

The three Argo Rollouts concepts are different:

| Resource | Role |
| --- | --- |
| `Rollout` | Owns the canary progression steps and decides when analysis should run. |
| `AnalysisTemplate` | Defines reusable metric queries, thresholds, intervals, and failure limits. |
| `AnalysisRun` | Runtime execution created from a template during a rollout step. |

In interview language:

```text
The Rollout is the workflow, the AnalysisTemplate is the test definition, and
the AnalysisRun is the test execution for a specific release attempt.
```

## Offline Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-analysis-wiring.ps1
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
```

The verifier checks that:

* the Rollout renders in Helm output
* both AnalysisTemplates render
* the Rollout references both templates after pause windows
* each template is referenced twice, once after the 20% pause and once after the
  50% pause
* the chart documentation, knowledge note, interview Q&A, and this runbook
  explain the same wiring contract

## Live Validation

In a dev cluster:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon
kubectl get analysisrun -n cpemon
kubectl describe analysisrun -n cpemon
```

Expected behavior:

```text
20% traffic -> pause -> AnalysisRun for 5xx and p95 -> 50% traffic -> pause -> AnalysisRun for 5xx and p95 -> 100%
```

If the analysis succeeds, the rollout can continue. If either metric fails, the
rollout should stop progressing and expose a failed AnalysisRun for inspection.

## Troubleshooting

If AnalysisRuns are not created:

1. Render the chart and confirm the Rollout has `analysis` steps.
2. Confirm the referenced AnalysisTemplate names match exactly.
3. Confirm Argo Rollouts CRDs and controller are installed.
4. Inspect the Rollout events.
5. Confirm the Rollout reached the step that contains analysis.

Commands:

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
kubectl describe rollout cpemon-api -n cpemon
kubectl get events -n cpemon --sort-by=.lastTimestamp
kubectl get analysistemplate -n cpemon
kubectl get analysisrun -n cpemon
```

## Interview Framing

The strong interview answer is:

```text
I did not just define Prometheus queries. I wired them into the Rollout after
pause windows so Prometheus has time to scrape canary traffic. The Rollout
creates AnalysisRuns from the 5xx and p95 AnalysisTemplates, and those runtime
results decide whether the canary can receive more traffic.
```
