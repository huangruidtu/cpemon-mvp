# Monitoring and Observability Upgrade

Story 12 upgrades CPEmon observability from "some endpoints and dashboards" into
a repo-controlled operating model for metrics, alerts, dashboards, logs, and
tracing.

## GitOps Boundary

The monitoring stack is a platform add-on. Argo CD owns the
`monitoring-dev` Application, which installs kube-prometheus-stack into the
`monitoring` namespace.

The application layer does not install Prometheus itself. Instead, CPEmon
workloads expose metrics on a stable port, and repo-owned ServiceMonitor,
PrometheusRule, and Grafana dashboard manifests attach those workloads to the
shared stack.

## Why kube-prometheus-stack?

kube-prometheus-stack packages:

| Component | Purpose |
| --- | --- |
| Prometheus Operator | Reconciles Prometheus CRDs such as ServiceMonitor and PrometheusRule. |
| Prometheus | Scrapes and stores metrics. |
| Grafana | Visualizes operational dashboards. |
| Alertmanager | Routes alerts. |
| kube-state-metrics and node-exporter | Provide Kubernetes object and node metrics. |

## CCPU-105 Learning Notes

The important design decision is ownership, not the Helm command.

In an interview, say:

> I kept kube-prometheus-stack in the platform GitOps layer and kept
> application-specific observability resources beside the app. That gives one
> shared Prometheus/Grafana control plane while still letting each service own
> the metrics, dashboards, and alerts that describe its behavior.

## Validation

```powershell
make monitoring-gitops-check
make monitoring-template
```

Live validation:

```powershell
kubectl get application monitoring-dev -n argocd
kubectl get pods,svc -n monitoring
kubectl get servicemonitor -A
kubectl get prometheusrule -A
```
