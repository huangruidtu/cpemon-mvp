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
