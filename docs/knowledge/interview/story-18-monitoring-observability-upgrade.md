# Story 18 - Monitoring and Observability Upgrade

## Interview Narrative

I upgraded CPEmon observability by making kube-prometheus-stack a GitOps-managed
platform add-on and then attaching application metrics, dashboards, alerts, and
tracing to that shared control plane. The key decision was separation of
ownership: the platform owns Prometheus, Grafana, Alertmanager, and CRDs; the
application owns the metrics, ServiceMonitor selectors, dashboards, alert rules,
and trace/log context that explain its runtime behavior.

## Q1: Why is monitoring managed as a platform add-on?

Monitoring is shared infrastructure. Prometheus Operator, Prometheus, Grafana,
Alertmanager, CRDs, and scrape policies affect the whole cluster. Managing them
once through Argo CD gives repeatability and avoids every service creating its
own observability stack.

## Q2: What does the application still own?

The application owns what it exposes and what it wants to observe: `/metrics`,
low-cardinality metric names and labels, ServiceMonitor selection, dashboards,
PrometheusRule alerts, trace propagation, and structured log fields.

## Q3: Why set the ServiceMonitor selector policy explicitly?

kube-prometheus-stack can restrict discovery to Helm-owned resources. CPEmon
sets `serviceMonitorSelectorNilUsesHelmValues`,
`podMonitorSelectorNilUsesHelmValues`, and `ruleSelectorNilUsesHelmValues` to
`false` so repo-owned ServiceMonitors and PrometheusRules can be discovered.

## Q4: How would you validate the monitoring stack?

First render the chart and run repository checks. Then inspect the Argo CD
Application, Prometheus pods, Grafana service, ServiceMonitors, PrometheusRules,
and Prometheus targets in the live cluster.

## Q5: What is the Prometheus Operator contract for application scraping?

The contract is `ServiceMonitor`. The application exposes a Service with a named
metrics port, and the ServiceMonitor selects that Service and defines the scrape
path, interval, timeout, and labels expected by the Prometheus instance.

For CPEmon, the key values are `release: kps`, namespace `monitoring`, workload
namespace `cpemon`, port `metrics`, path `/metrics`, and selectors for
`cpemon-api`, `acs-ingest`, and `cpemon-writer`.

## Q6: What breaks ServiceMonitor scraping most often?

The common failures are missing CRDs, wrong namespace, missing `release: kps`,
selector labels that do not match the Service, a Service port not named
`metrics`, or an application that does not actually serve `/metrics`.
