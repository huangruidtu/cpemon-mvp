# Argo Rollouts Canary Deployment

Story 13 introduces Argo Rollouts as the progressive delivery layer for CPEmon.

## CCPU-114: Install Argo Rollouts Controller

The first boundary is the controller, not the application Rollout.

```text
Git desired state -> Argo CD -> argo-rollouts controller -> Rollout resources
```

The repository represents the controller as:

```text
k8s/gitops/dev/applications/argo-rollouts-dev.yaml
k8s/addons/argo-rollouts/values.yaml
```

The chart is pinned to:

```text
chart:       argo-rollouts
version:     2.41.0
app version: v1.9.0
namespace:   argo-rollouts
```

Why the controller is separate from CPEmon:

* it installs cluster CRDs such as `Rollout` and `AnalysisTemplate`
* it watches deployment state for any service that adopts Rollouts
* it is upgraded and operated by the platform delivery layer
* it should not be duplicated by every application chart

The CPEmon chart can later define the `Rollout`, stable Service, canary
Service, canary steps, and analysis references. Those are application delivery
resources. The controller is shared infrastructure.

## Validation Boundary

Static repository validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argo-rollouts-controller.ps1
```

Chart render validation:

```powershell
helm template argo-rollouts argo/argo-rollouts `
  --namespace argo-rollouts `
  --version 2.41.0 `
  --values k8s/addons/argo-rollouts/values.yaml
```

Live cluster validation:

```powershell
kubectl get application argo-rollouts-dev -n argocd
kubectl get pods,deploy,svc -n argo-rollouts
kubectl rollout status deploy/argo-rollouts -n argo-rollouts --timeout=5m
kubectl get crd | Select-String "argoproj.io"
```

## Mental Model

Argo CD answers: "Does the cluster match Git?"

Argo Rollouts answers: "How should this workload move from old version to new
version safely?"

Prometheus analysis answers: "Is the new version healthy enough to continue?"

Keeping those boundaries separate makes the architecture easier to explain and
debug.

## CCPU-188: Add Argo Rollouts kubectl Plugin and Local Tooling

The kubectl plugin is not the controller. It is local operator tooling that
makes progressive delivery easier to inspect and demonstrate.

Controller path:

```text
Argo CD -> argo-rollouts controller -> Kubernetes Rollout reconciliation
```

Operator tooling path:

```text
kubectl argo rollouts -> inspect/promote/abort/retry/watch Rollouts
```

The project pins the plugin to `v1.9.0`, matching the Argo Rollouts controller
app version from chart `2.41.0`.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argo-rollouts-local-tooling.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-argo-rollouts-local-tooling.ps1 -RequireInstalledPlugin
kubectl argo rollouts version
kubectl plugin list
```

Windows gotcha:

`kubectl` discovers plugins from executable files on `PATH` named with the
`kubectl-<name>` convention. For Argo Rollouts on Windows, the expected file is
`kubectl-argo-rollouts.exe`. If it exists under `C:\Users\Rui Huang\bin` but
`kubectl argo rollouts version` fails, prepend that directory to `PATH` or add
it to the permanent user PATH.

Interview point:

The plugin is useful because canary releases are operational workflows, not
just YAML. During a demo or incident, operators need fast status, promotion,
abort, and retry commands without hand-writing JSONPath queries.

## CCPU-115: Replace cpemon-api Deployment with Rollout

The first application migration step is deliberately narrow: only `cpemon-api`
gets a Rollout rendering path.

```yaml
workloads:
  cpemonApi:
    rollout:
      enabled: true
```

When enabled, the chart renders:

```text
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata.name: cpemon-api
```

The other application workloads still render as Deployments:

```text
acs-ingest     -> Deployment
cpemon-writer  -> Deployment
```

This is the safest migration shape because it keeps the blast radius to one
user-facing API workload while preserving the same pod template, probes, ports,
environment variables, Secret references, labels, and ServiceMonitor
compatibility.

The initial canary strategy has `steps: []`. That means this subtask proves the
controller-kind migration first. Later subtasks add stable/canary Services,
traffic weights, and Prometheus analysis.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-rollout.ps1
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

## CCPU-116: Create Stable and Canary Services

Argo Rollouts needs service boundaries so stable and canary ReplicaSets can be
addressed separately.

The chart now renders three Services for `cpemon-api` when Rollout mode is
enabled:

```text
cpemon-api          existing application Service
cpemon-api-stable   stable traffic boundary
cpemon-api-canary   canary traffic boundary
```

The Rollout strategy references:

```yaml
strategy:
  canary:
    stableService: cpemon-api-stable
    canaryService: cpemon-api-canary
```

The stable and canary Services initially use the same selector labels as the
Rollout pod template:

```text
app=cpemon-api
app.kubernetes.io/instance=cpemon
app.kubernetes.io/component=api
```

In a live cluster, the Rollouts controller can update stable/canary service
selectors as ReplicaSets move through the rollout. That is why service
inspection matters during demos:

```powershell
kubectl get svc cpemon-api cpemon-api-stable cpemon-api-canary -n cpemon
kubectl get endpoints cpemon-api-stable cpemon-api-canary -n cpemon
kubectl describe svc cpemon-api-stable -n cpemon
kubectl describe svc cpemon-api-canary -n cpemon
```

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-rollout-services.ps1
```

## CCPU-117: Configure Canary Steps

The first canary ladder is simple enough to explain during an interview and
safe enough to operate manually:

```yaml
steps:
  - setWeight: 20
  - pause:
      duration: 60s
  - setWeight: 50
  - pause:
      duration: 120s
  - setWeight: 100
```

Why this shape:

* `20%` gives the new ReplicaSet real traffic while limiting blast radius.
* The first pause gives the operator a fast check window.
* `50%` proves the canary under more meaningful load.
* The second pause gives time to inspect metrics, logs, traces, and rollout
  status before full promotion.
* `100%` completes promotion after the operator is comfortable.

This is still a manual promotion ladder. It does not yet include Prometheus
analysis. The next analysis subtasks add metric-based gates for HTTP 5xx rate
and p95 latency.

Useful commands:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon
kubectl argo rollouts promote cpemon-api -n cpemon
kubectl argo rollouts abort cpemon-api -n cpemon
```

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-canary-steps.ps1
```

## CCPU-189: Add Prometheus AnalysisTemplate for HTTP 5xx Rate

The first automated canary signal is HTTP 5xx rate for `cpemon-api`.

The focused runbook is:

```text
ops/runbooks/cpemon-api-http5xx-analysis.md
```

Template:

```text
AnalysisTemplate/cpemon-api-http-5xx-rate
```

Metric:

```text
cpemon_api_http_requests_total
```

Query:

```promql
sum(rate(cpemon_api_http_requests_total{code=~"5.."}[2m]))
/
clamp_min(sum(rate(cpemon_api_http_requests_total[2m])), 1)
```

Threshold:

```text
successCondition: result[0] < 0.05
```

Why this signal:

* 5xx responses indicate server-side failure.
* The metric uses bounded labels such as `code`, not device identifiers.
* A ratio is better than a raw count because it accounts for traffic volume.
* `clamp_min(..., 1)` avoids divide-by-zero behavior when there is little or no
  traffic in a dev environment.

This subtask only renders the AnalysisTemplate. It does not yet attach the
template to the Rollout. That connection happens after both 5xx and p95 latency
templates exist.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-http5xx-analysis.ps1
```

## CCPU-121: Create AnalysisTemplate for 5xx Rate

`CCPU-121` closes the 5xx gate as an interview-ready implementation task. The
resource already renders from Helm, and the runbook records the operational
contract:

```text
metric: cpemon_api_http_requests_total
query: 5xx request rate / total request rate
threshold: result[0] < 0.05
resource: AnalysisTemplate/cpemon-api-http-5xx-rate
```

The key design choices are:

* Use a ratio instead of a raw count, because traffic volume changes the meaning
  of an error count.
* Use bounded labels, especially HTTP status code, so the query is safe for
  release automation.
* Use `clamp_min` on the denominator so low-traffic windows do not create
  divide-by-zero behavior.
* Keep the threshold in chart values so reviewers can tune it without rewriting
  templates.

In an interview, describe this as the first automated reliability gate: Argo
Rollouts asks Prometheus whether the canary is producing too many server
errors, and promotion stops when the signal crosses the configured threshold.

## CCPU-190: Add Prometheus AnalysisTemplate for p95 Latency

The second automated canary signal is p95 latency.

The focused runbook is:

```text
ops/runbooks/cpemon-api-p95-latency-analysis.md
```

Template:

```text
AnalysisTemplate/cpemon-api-p95-latency
```

Metric:

```text
cpemon_api_http_request_duration_seconds_bucket
```

Query:

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(cpemon_api_http_request_duration_seconds_bucket[2m])
  )
)
```

Threshold:

```text
successCondition: result[0] < 0.5
```

Why this signal:

* 5xx rate catches failed requests.
* p95 latency catches slow successful requests.
* Histograms are the Prometheus-native way to calculate quantiles.
* Grouping by `le` preserves the histogram buckets needed by
  `histogram_quantile`.

This template is also rendered independently first. The Rollout connects both
5xx and p95 templates in a later subtask.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-p95-analysis.ps1
```

## CCPU-122: Create AnalysisTemplate for p95 Latency

`CCPU-122` closes the latency gate as an interview-ready implementation task.
The resource already renders from Helm, and the runbook records the operational
contract:

```text
metric: cpemon_api_http_request_duration_seconds_bucket
query: histogram_quantile(0.95, sum by (le) rate(...[2m]))
threshold: result[0] < 0.5
resource: AnalysisTemplate/cpemon-api-p95-latency
```

The key design choices are:

* Use p95 instead of average latency because a canary can hurt a meaningful
  tail of users while the mean still looks acceptable.
* Use Prometheus histogram buckets because quantiles should be calculated from
  bucketed duration observations.
* Preserve the `le` label with `sum by (le)` because `histogram_quantile`
  needs bucket boundaries.
* Pair p95 with 5xx rate so rollout safety covers both failed requests and slow
  successful requests.

In an interview, describe this as the user-experience gate: Argo Rollouts asks
Prometheus whether the canary is too slow before allowing it to receive more
traffic.

## CCPU-191: Connect AnalysisTemplates to Rollout

The Rollout now runs both quality gates after the 20% and 50% pause windows:

The focused runbook is:

```text
ops/runbooks/cpemon-api-analysis-wiring.md
```

```yaml
- analysis:
    templates:
      - templateName: cpemon-api-http-5xx-rate
      - templateName: cpemon-api-p95-latency
```

The full canary flow is:

```text
20% traffic
  -> pause 60s
  -> run 5xx and p95 analysis
  -> 50% traffic
  -> pause 120s
  -> run 5xx and p95 analysis again
  -> 100% traffic
```

Why after pauses:

* The pause gives Prometheus enough time to scrape and aggregate data.
* The analysis gate evaluates the canary before the next traffic increase.
* Running the same checks again at 50% catches failures that only appear under
  more meaningful load.

Live inspection commands:

```powershell
kubectl get analysisrun -n cpemon
kubectl describe analysisrun -n cpemon
kubectl argo rollouts get rollout cpemon-api -n cpemon
```

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-analysis-wiring.ps1
```

## CCPU-123: Connect AnalysisTemplates to Rollout

`CCPU-123` closes the wiring between metric definitions and rollout behavior.
The important distinction is:

```text
AnalysisTemplate: reusable metric contract
AnalysisRun: runtime execution for one rollout attempt
Rollout step: the point where the controller creates the AnalysisRun
```

The chart wires both checks after each pause:

```text
20% traffic -> pause 60s -> run 5xx and p95 analysis
50% traffic -> pause 120s -> run 5xx and p95 analysis
```

This order gives Prometheus time to scrape canary traffic before Argo Rollouts
uses the metric result to decide whether promotion can continue.

In an interview, the key is to avoid saying "I added Prometheus." The stronger
answer is: "I connected Prometheus-backed AnalysisTemplates to the Rollout
workflow so each promotion step creates AnalysisRuns and uses runtime evidence
before increasing traffic."

## CCPU-118: Verify Rollout Status with kubectl argo rollouts

The operator status command is:

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon
```

The command gives a rollout-centered view: current phase, step, traffic weight,
ReplicaSets, pods, and AnalysisRuns.

Important companion checks:

```powershell
kubectl get rollout cpemon-api -n cpemon -o yaml
kubectl get rs,pods,svc,endpoints,analysisrun -n cpemon -l app=cpemon-api
kubectl describe rollout cpemon-api -n cpemon
kubectl describe analysisrun -n cpemon
```

Status meanings:

* Healthy means the rollout completed or is serving the desired version.
* Progressing means the rollout is moving through steps or waiting for pods and
  analysis.
* Paused means the rollout is intentionally waiting at a decision point.
* Degraded means the controller has evidence of failure.
* Aborted means rollout progression was stopped and should not be promoted.

The runbook is:

```text
ops/runbooks/argo-rollouts-cpemon-api.md
```

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-rollout-status-runbook.ps1
```

## CCPU-119: Test Manual Promote and Abort

Manual rollout control uses the plugin:

```powershell
kubectl argo rollouts promote cpemon-api -n cpemon
kubectl argo rollouts abort cpemon-api -n cpemon
```

Use promote when the canary evidence is good:

```text
pods ready
AnalysisRuns passed
5xx below threshold
p95 below threshold
service endpoints make sense
logs and traces do not show a new failure pattern
```

Use abort when the canary is unsafe:

```text
AnalysisRun failed
canary pods are not ready
5xx or p95 regression appears
canary Service has no endpoints
operator cannot explain the current state
```

The full promotion command exists:

```powershell
kubectl argo rollouts promote cpemon-api -n cpemon --full
```

For interviews, explain that `--full` is a demo shortcut, not the default
production habit. The safer production habit is step-by-step promotion after
each pause and analysis result.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-promote-abort-runbook.ps1
```

## CCPU-192: Healthy Canary Demo Scenario

The healthy canary demo is:

```text
ops/demos/argo-rollouts/cpemon-api-healthy-canary.md
```

It demonstrates the good path:

```text
stable traffic
new canary ReplicaSet
20% traffic
successful 5xx and p95 analysis
50% traffic
successful 5xx and p95 analysis
100% traffic
Healthy rollout
```

The key learning point is that a successful rollout is still evidence-driven.
Even when the canary is expected to pass, the operator checks:

* Rollout phase and current step.
* ReplicaSet and pod readiness.
* Stable and canary Service endpoints.
* AnalysisRun status.
* 5xx and p95 metric thresholds.
* Logs and traces for new error patterns.

In an interview, this is the difference between "I deployed something" and "I
can operate a progressive delivery workflow safely."

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-healthy-canary-demo.ps1
```

## CCPU-193: Failed Canary Demo Scenario

The failed canary demo is:

```text
ops/demos/argo-rollouts/cpemon-api-failed-canary.md
```

It demonstrates the protected failure path:

```text
stable traffic
bad canary ReplicaSet
limited canary exposure
failed 5xx or p95 analysis
Degraded or Aborted rollout
stable path remains available
```

The important lesson is blast-radius reduction. A bad release is allowed to
prove itself under small exposure, but it is not allowed to silently become the
stable version when runtime evidence is bad.

Good interview language:

```text
I do not need to prove that deployments never fail. I need to prove that when a
deployment fails, the platform detects it, limits exposure, preserves a stable
serving path, and gives operators enough evidence to decide rollback, retry, or
fix forward.
```

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-failed-canary-demo.ps1
```

## CCPU-194: Successful Rollout Demo Script

The successful rollout script is:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/demo-cpemon-api-successful-rollout.ps1
```

It defaults to dry-run mode so the command sequence can be rehearsed safely on
a workstation. With `-Execute`, it runs the live `kubectl` commands against the
current dev cluster context.

The script produces the same evidence the interview story needs:

* Starting rollout status.
* Stable and canary endpoint inspection.
* Rollout watch through pause and analysis gates.
* AnalysisRun inspection.
* Step-by-step promote commands.
* Final Healthy rollout check.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-successful-rollout-demo-script.ps1
```

## CCPU-195: Failed Rollout Demo Script

The failed rollout script is:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/demo-cpemon-api-failed-rollout.ps1
```

It defaults to dry-run mode and prints the failed-canary investigation and abort
sequence. With `-Execute`, it checks the current dev cluster context and runs
the live commands.

The script demonstrates rollback safety by collecting:

* Starting rollout status.
* Stable and canary endpoints.
* Failed AnalysisRun details.
* ReplicaSet, pod, service, and endpoint evidence.
* Abort command and post-abort verification.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-failed-rollout-demo-script.ps1
```

## CCPU-196: Rollback, ADR, Runbook, and Interview Notes

The long-lived decision record is:

```text
ADR/cloud-platform-upgrade-argo-rollouts-canary-deployment.md
```

The runbook is:

```text
ops/runbooks/argo-rollouts-cpemon-api.md
```

The two demo paths are:

```text
ops/demos/argo-rollouts/cpemon-api-healthy-canary.md
ops/demos/argo-rollouts/cpemon-api-failed-canary.md
```

The core interview distinction:

```text
abort stops unsafe in-flight rollout progression
rollback changes Git desired state back to a known-good version
```

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argo-rollouts-final-docs.ps1
```

## CCPU-197: Prometheus Metrics and Query Inputs

The Prometheus input runbook is:

```text
ops/runbooks/cpemon-api-prometheus-analysis-inputs.md
```

The analysis gates depend on these metrics:

```text
cpemon_api_http_requests_total
cpemon_api_http_request_duration_seconds_bucket
```

The important learning point is that an AnalysisTemplate has two contracts:

```text
manifest contract: Helm renders the expected query
runtime contract: Prometheus has fresh samples with safe labels
```

Offline checks prove the manifest contract. Live checks against a dev
Prometheus instance prove the runtime contract.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-prometheus-analysis-inputs.ps1
```
