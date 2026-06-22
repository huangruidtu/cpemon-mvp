# ADR: Monitoring and Observability Upgrade

Status: Accepted

Date: 2026-06-22

## Context

CPEmon started with local Kubernetes manifests and a small set of health checks.
The cloud platform upgrade needs an observability model that can be operated in
EKS and explained clearly in interviews.

Story 12 adds observability across the CPEmon event path:

* platform monitoring through Argo CD and kube-prometheus-stack
* CPEmon ServiceMonitor resources through Helm
* application metrics for `acs-ingest`, `cpemon-writer`, and `cpemon-api`
* Kafka metrics boundary through JMX exporter and ServiceMonitor intent
* Grafana dashboards for pipeline health and API health
* PrometheusRule alert baseline
* OpenTelemetry Collector and Tempo trace export boundary
* `trace_id` propagation into structured logs
* repository and live-cluster validation guidance

## Decision

Use a layered observability model:

1. Platform owns the monitoring control plane with Argo CD.
2. Applications expose metrics and define their own ServiceMonitor, dashboard,
   and alert artifacts.
3. Prometheus stores low-cardinality metrics.
4. Grafana is the primary operator UI for dashboards and traces.
5. Tempo is the first trace backend.
6. Logs carry `trace_id` for concrete request debugging.
7. Validation is split into Repository proof, Render proof, and Live cluster
   proof.

## Rationale

This keeps ownership clean. The platform team owns shared Prometheus, Grafana,
Alertmanager, CRDs, and Argo CD lifecycle. Application code owns the signals
that describe CPEmon behavior.

Prometheus is the right tool for rates, errors, durations, scrape health, retry
counts, dead-letter counts, and Kafka broker metrics. It is not the right place
for device serial numbers, raw payload details, or per-request debugging.

Tempo fits this story because Grafana already anchors dashboards. Jaeger is a
valid alternative, but Tempo gives a simpler first learning path for metrics,
logs, and traces in one UI.

## Consequences

Positive:

* The system has one coherent operator workflow.
* Interview answers can distinguish metrics, logs, traces, dashboards, and
  alerts with CPEmon-specific evidence.
* Low-cardinality metric labels protect Prometheus from series explosion.
* `trace_id` gives a concrete bridge from logs to traces.
* Repository validation can run without a live EKS cluster.

Tradeoffs:

* Live proof still requires a reachable Kubernetes cluster and real Prometheus,
  Grafana, and Tempo instances.
* The first Tempo deployment uses local storage for dev learning, not production
  retention.
* Full application span instrumentation can be expanded later; this story
  establishes context propagation and backend boundaries first.

## Validation

Repository proof:

```powershell
make observability-e2e-check
go test ./...
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
```

Live cluster proof:

```powershell
kubectl get application monitoring-dev -n argocd
kubectl get pods,svc -n monitoring
kubectl get pods,svc -n observability
kubectl get servicemonitor -A
kubectl get prometheusrule -A
kubectl logs deploy/otel-collector -n observability
```

Then use Grafana to inspect dashboards and Tempo to search for a `trace_id`
from a structured API request log.
