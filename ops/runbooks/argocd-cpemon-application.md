# Argo CD CPEmon Application Runbook

This runbook validates the `cpemon-dev` Argo CD Application.

## Purpose

`cpemon-dev` connects Argo CD to the CPEmon Helm chart in Git:

```text
Application:   cpemon-dev
Project:       cpemon
Source repo:   https://github.com/huangruidtu/cpemon-mvp.git
Source path:   deploy/helm/cpemon
Values file:   values-dev.yaml
Destination:   https://kubernetes.default.svc / cpemon
```

The Application does not build images. CI builds, tests, and publishes images.
Git records the desired image tag and chart values. Argo CD reconciles the
cluster to the Git state.

## Static Validation

Run the repository check:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-cpemon-application.ps1
```

Render the chart with the same values file referenced by the Application:

```powershell
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

## Live Validation

Apply the Application after Argo CD and the `cpemon` AppProject exist:

```powershell
kubectl apply -f k8s/addons/argocd/namespace.yaml
kubectl apply -f k8s/addons/argocd/projects/cpemon-project.yaml
kubectl apply -f k8s/gitops/dev/applications/cpemon-dev.yaml
```

Inspect Argo CD state:

```powershell
kubectl get application cpemon-dev -n argocd
kubectl describe application cpemon-dev -n argocd
```

If the Argo CD CLI is installed:

```powershell
argocd app get cpemon-dev
```

## Expected State

* `Synced` means Argo CD sees live Kubernetes resources matching the Git
  desired state at the configured revision.
* `OutOfSync` means Git and the cluster differ.
* `Healthy` means the rendered Kubernetes resources report a good runtime
  state.
* `Degraded` or `Missing` usually points to workload, dependency, or namespace
  readiness issues.

## Image Tag Ownership

`deploy/helm/cpemon/values-dev.yaml` currently uses the placeholder
`__IMAGE_TAG__`.

For a real sync, CI should promote a concrete image tag into Git before Argo CD
syncs. In interviews, describe this as the separation between artifact
creation and deployment intent:

```text
GitHub Actions -> build and push image
Git commit     -> record desired image tag
Argo CD        -> deploy recorded desired state
```

## Dependencies

Before expecting `Healthy`, confirm:

* the `cpemon` namespace exists
* database and HMAC Secrets exist, or External Secrets is enabled and healthy
* Kafka is reachable if the Kafka consumer mode is enabled
* any optional monitoring CRDs exist before enabling `ServiceMonitor`
