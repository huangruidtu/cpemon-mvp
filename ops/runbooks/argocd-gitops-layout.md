# Argo CD GitOps Layout Runbook

This runbook covers `CCPU-175: Define GitOps repository layout and application
boundary`.

## Purpose

The GitOps layout answers a practical question:

> When Argo CD reconciles CPEmon, which files are the desired state?

The repository separates Argo CD bootstrap resources from Argo CD Application
resources.

## Directory Boundaries

Argo CD bootstrap:

```text
k8s/addons/argocd/
```

This includes:

* `namespace.yaml`
* `projects/cpemon-project.yaml`

Argo CD Applications:

```text
k8s/gitops/dev/applications/
```

This will contain the dev environment Application manifests.

Helm chart sources:

```text
deploy/helm/cpemon
deploy/helm/cpemon/values-dev.yaml
```

Platform add-on sources:

```text
k8s/addons/kafka
k8s/addons/metrics-server
k8s/addons/aws-load-balancer-controller
```

## App-Of-Apps Decision

Story 11 does not start with app-of-apps.

Decision:

* Use plain Argo CD `Application` manifests first.
* Put them in `k8s/gitops/dev/applications`.
* Defer a root Application until multiple environments or many Applications
  make it useful.

Why:

* It is easier to inspect every Application directly.
* The learning environment has one cluster and one environment.
* The story can focus on Argo CD behavior before adding orchestration
  indirection.

## Validation

Repository validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-gitops-layout.ps1
```

Live validation later:

```powershell
kubectl get applications -n argocd
kubectl describe application cpemon-dev -n argocd
argocd app list
```

## Interview Explanation

The layout is part of the architecture. Bootstrap manifests prepare Argo CD;
Application manifests tell Argo CD what to reconcile; Helm charts and values
remain the deployable workload source. This separation keeps CI/CD
responsibilities clear and makes GitOps debugging easier.

