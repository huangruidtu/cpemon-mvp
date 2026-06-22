# Monitoring and Observability Runbook

This runbook explains how CPEmon operates the shared monitoring stack and how
application observability resources attach to it.

## Platform Boundary

The monitoring control plane is managed as a platform add-on:

| Concern | Owner | Repo location |
| --- | --- | --- |
| Prometheus Operator, Prometheus, Grafana, Alertmanager | Platform | `k8s/gitops/dev/applications/monitoring-dev.yaml` |
| kube-prometheus-stack values | Platform | `k8s/monitoring/kube-prometheus-stack-values.yaml` |
| CPEmon ServiceMonitor | Application/platform contract | `deploy/helm/cpemon/templates/servicemonitor.yaml` |
| CPEmon dashboards and alerts | Application observability | `k8s/monitoring/` |

The Argo CD Application uses the `kube-prometheus-stack` chart from
`ghcr.io/prometheus-community/charts`, release name `kps`, namespace
`monitoring`, and values from this repository.

## Repository Validation

```powershell
make monitoring-gitops-check
make monitoring-template
```

`monitoring-gitops-check` verifies that the GitOps Application, chart version,
values file, selector policy, runbook, knowledge notes, and interview notes are
present. `monitoring-template` renders the upstream chart with CPEmon values.

## Live Checks

```powershell
kubectl get application monitoring-dev -n argocd
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get servicemonitor -A
kubectl get prometheusrule -A
```

Prometheus:

```powershell
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090
```

Grafana:

```powershell
kubectl port-forward svc/kps-grafana -n monitoring 3000:80
```

## Debug Drill: Monitoring Application Is OutOfSync

1. Inspect the Argo CD Application:

   ```powershell
   kubectl describe application monitoring-dev -n argocd
   ```

2. Confirm the chart version and values file are reachable.
3. Render locally with `make monitoring-template`.
4. Check whether CRDs, namespace creation, or Helm values changed.

## Debug Drill: ServiceMonitor Is Not Scraped

Check these in order:

1. The ServiceMonitor CRD exists.
2. The ServiceMonitor is in the expected namespace.
3. The ServiceMonitor has `release: kps`.
4. The Service selector matches the CPEmon Services.
5. The selected Service exposes a port named `metrics`.
6. The workload serves `/metrics` on port `9100`.

## Interview Framing

The clean answer is:

> I managed monitoring as a platform add-on through Argo CD because Prometheus,
> Grafana, Alertmanager, CRDs, and operators are shared cluster capabilities.
> Applications expose metrics and define dashboards or alerts, but the platform
> owns the monitoring control plane. That separation prevents every service from
> installing its own Prometheus stack and gives the team one observable cluster
> contract.
