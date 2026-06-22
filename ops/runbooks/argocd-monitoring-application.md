# Argo CD Monitoring Application Runbook

This runbook validates the `monitoring-dev` Argo CD Application.

## Purpose

`monitoring-dev` brings kube-prometheus-stack into the GitOps model.

```text
Application:    monitoring-dev
Project:        cpemon
Chart repo:     ghcr.io/prometheus-community/charts
Chart:          kube-prometheus-stack
Chart version:  86.3.2
Release name:   kps
Values source:  https://github.com/huangruidtu/cpemon-mvp.git
Values file:    k8s/monitoring/kube-prometheus-stack-values.yaml
Destination:    https://kubernetes.default.svc / monitoring
```

Monitoring is a platform add-on. It owns Prometheus, Grafana, Alertmanager,
Prometheus Operator CRDs, and cluster-level scrape/rule capabilities. CPEmon
application workloads should expose metrics, but they should not own the
monitoring control plane.

## Static Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-monitoring-application.ps1
```

Render the same chart and values locally:

```powershell
helm template kps oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack `
  --namespace monitoring `
  --version 86.3.2 `
  --values k8s/monitoring/kube-prometheus-stack-values.yaml
```

## Live Validation

Apply after Argo CD and the `cpemon` AppProject exist:

```powershell
kubectl apply -f k8s/addons/argocd/projects/cpemon-project.yaml
kubectl apply -f k8s/gitops/dev/applications/monitoring-dev.yaml
```

Inspect the Application:

```powershell
kubectl get application monitoring-dev -n argocd
kubectl describe application monitoring-dev -n argocd
```

If the Argo CD CLI is installed:

```powershell
argocd app get monitoring-dev
```

Inspect runtime resources:

```powershell
kubectl get pods,svc,statefulset,deploy -n monitoring
kubectl get crd | Select-String "monitoring.coreos.com"
kubectl get prometheus,alertmanager,servicemonitor,prometheusrule -n monitoring
```

## CRD and Ordering Notes

kube-prometheus-stack installs Prometheus Operator CRDs such as
`ServiceMonitor` and `PrometheusRule`.

The repository also contains CPEmon-specific monitoring resources:

```text
k8s/monitoring/servicemonitor-cpemon.yaml
k8s/monitoring/servicemonitor-acs-ingest.yaml
k8s/monitoring/cpemon-alerts-prometheusrule.yaml
k8s/monitoring/grafana-dashboard-cpemon-pipeline.yaml
```

Those resources depend on the monitoring CRDs and selectors created by the
stack. Sync the monitoring stack first, then sync or apply CPEmon-specific
monitoring resources after the CRDs exist.

## Expected State

`Synced` means Argo CD rendered and applied the pinned chart with the CPEmon
values file.

`Healthy` requires:

* Prometheus Operator running
* Prometheus StatefulSet ready
* Grafana Deployment ready
* Alertmanager ready
* CRDs established
* required PVCs and admission webhooks healthy

## Interview Framing

Monitoring is managed as a platform add-on because it is shared
infrastructure. It provides CRDs, scrape discovery, alert evaluation, and
dashboards used by multiple workloads. The application chart can expose
metrics and optional ServiceMonitors, but the observability control plane
belongs to the platform layer.
