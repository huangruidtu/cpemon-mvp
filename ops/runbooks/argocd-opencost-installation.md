# Argo CD OpenCost Installation Runbook

This runbook validates the `opencost-dev` Argo CD Application.

## Application Contract

```text
Application:    opencost-dev
Project:        cpemon
Chart repo:     https://opencost.github.io/opencost-helm-chart
Chart:          opencost
Chart version:  2.5.23
App version:    1.120.3
Release name:   opencost
Values source:  https://github.com/huangruidtu/cpemon-mvp.git
Values file:    k8s/addons/opencost/values.yaml
Destination:    https://kubernetes.default.svc / opencost
Sync policy:    manual
```

OpenCost is installed as platform cost visibility infrastructure. Step 1 is
visibility, not chargeback. The goal is to make namespace and workload cost
signals available before attempting allocation, optimization, or budgets.

## Local Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-opencost-installation.ps1
```

Render the chart locally:

```powershell
helm repo add opencost https://opencost.github.io/opencost-helm-chart
helm repo update opencost
helm template opencost opencost/opencost `
  --version 2.5.23 `
  --namespace opencost `
  --values k8s/addons/opencost/values.yaml
```

## Apply Through Argo CD

```powershell
kubectl apply -f k8s/addons/argocd/projects/cpemon-project.yaml
kubectl apply -f k8s/gitops/dev/applications/opencost-dev.yaml
argocd app get opencost-dev
argocd app diff opencost-dev
argocd app sync opencost-dev
argocd app wait opencost-dev --sync --health --timeout 300
```

## Runtime Validation

```powershell
kubectl get pods,svc,deploy -n opencost
kubectl logs -n opencost deploy/opencost --tail=100
kubectl port-forward -n opencost svc/opencost 9090:9090
```

Then open:

```text
http://localhost:9090
```

Prometheus connection details are documented in the next subtask. This task
establishes the OpenCost installation boundary and service access path.

## Interview Framing

The concise answer:

```text
I added OpenCost as a GitOps-managed platform add-on so the platform can expose
namespace and workload cost visibility. I treated it as visibility first, not
chargeback, because teams need reliable cost signals before they can optimize
or allocate spend responsibly.
```
