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
