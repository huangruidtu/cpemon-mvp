# Argo Rollouts Controller Runbook

This runbook validates the `argo-rollouts-dev` Argo CD Application and the
controller boundary required before CPEmon can use canary `Rollout` resources.

## Purpose

Argo Rollouts is progressive delivery infrastructure. It reconciles `Rollout`,
`AnalysisTemplate`, and related resources, but it should not be installed by
the CPEmon application chart.

```text
Application:    argo-rollouts-dev
Project:        cpemon
Chart repo:     https://argoproj.github.io/argo-helm
Chart:          argo-rollouts
Chart version:  2.41.0
App version:    v1.9.0
Release name:   argo-rollouts
Values source:  https://github.com/huangruidtu/cpemon-mvp.git
Values file:    k8s/addons/argo-rollouts/values.yaml
Destination:    https://kubernetes.default.svc / argo-rollouts
```

## Ownership Boundary

Git owns:

* the Argo CD Application
* the controller Helm values
* the `argo-rollouts` namespace intent
* the AppProject source and destination permissions

The CPEmon application chart owns, in later subtasks:

* `Rollout` resources for workloads
* stable and canary Services
* canary steps
* Prometheus-backed AnalysisTemplates and AnalysisRuns

This separation matters because the controller is shared delivery
infrastructure, while Rollout resources are application deployment intent.

## Static Validation

Run the repository check:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argo-rollouts-controller.ps1
```

Render the controller chart locally:

```powershell
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo
helm template argo-rollouts argo/argo-rollouts `
  --namespace argo-rollouts `
  --version 2.41.0 `
  --values k8s/addons/argo-rollouts/values.yaml
```

## Live Validation

Apply the AppProject and Application after Argo CD is installed:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
kubectl apply -f k8s/addons/argocd/projects/cpemon-project.yaml
kubectl apply -f k8s/gitops/dev/applications/argo-rollouts-dev.yaml
```

Inspect Argo CD:

```powershell
kubectl get application argo-rollouts-dev -n argocd
kubectl describe application argo-rollouts-dev -n argocd
argocd app get argo-rollouts-dev
```

Inspect the controller:

```powershell
kubectl get pods,deploy,svc -n argo-rollouts
kubectl rollout status deploy/argo-rollouts -n argo-rollouts --timeout=5m
kubectl get crd | Select-String "argoproj.io"
```

If the kubectl plugin is installed in the next subtask:

```powershell
kubectl argo rollouts version
```

## Expected State

`Synced` means Argo CD applied the controller chart resources.

`Healthy` requires the controller Deployment to be available and the Argo
Rollouts CRDs to exist. CPEmon can only reconcile Rollout resources after this
controller path is healthy.

## Troubleshooting

If the Application is denied by the AppProject, confirm that
`https://argoproj.github.io/argo-helm` is listed in `sourceRepos` and
`argo-rollouts` is listed in `destinations`.

If Rollout manifests fail later with "no matches for kind Rollout", the CRDs
are missing or the controller Application has not completed successfully.

If the controller Deployment is unavailable, inspect:

```powershell
kubectl describe deploy argo-rollouts -n argo-rollouts
kubectl logs -n argo-rollouts deploy/argo-rollouts --tail=100
```

## Interview Framing

A strong interview answer is:

> I installed Argo Rollouts as platform delivery infrastructure through Argo CD,
> separate from the CPEmon application chart. The controller owns reconciliation
> for Rollout and Analysis resources; the application chart owns the per-service
> rollout strategy.
