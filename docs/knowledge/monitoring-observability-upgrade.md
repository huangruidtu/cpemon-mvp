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

## CCPU-106 Learning Notes: ServiceMonitor

`ServiceMonitor` is the Prometheus Operator contract between an application and
the shared Prometheus stack.

For CPEmon, the Helm chart renders one ServiceMonitor that discovers the three
application Services:

* `cpemon-api`
* `acs-ingest`
* `cpemon-writer`

The scrape contract is intentionally stable: port name `metrics`, path
`/metrics`, namespace `cpemon`, and Prometheus release label `kps`.

The important interview point is that Prometheus does not scrape pods just
because they exist. The operator watches ServiceMonitor resources, resolves
their selectors into Services, resolves Service ports into endpoints, and then
generates Prometheus scrape configuration.

## CCPU-181 Learning Notes: acs-ingest Metrics

`acs-ingest` is the first application boundary in the CPEmon pipeline. Its
metrics answer: are webhooks arriving, are they valid, how long does ingestion
take, how large are payloads, and where do failures occur before Kafka?

The metrics added for this boundary are:

| Metric | Why it matters |
| --- | --- |
| `acs_webhook_requests_total{code}` | Request success and error rates. |
| `acs_webhook_errors_total{reason}` | Bounded failure classification. |
| `acs_webhook_duration_seconds{code}` | Latency at the intake boundary. |
| `acs_webhook_payload_bytes` | Payload-size pressure and unusual request bodies. |
| `acs_ingest_events_total{result}` | Whether events were queued, rejected, or failed downstream. |

All labels are low-cardinality. Do not put `sn`, event IDs, raw Kafka keys, or
payload data into Prometheus labels.

## CCPU-107 Learning Notes: Kafka Metrics

Kafka metrics must be explained in two layers.

Broker metrics come from Kafka/JMX and answer platform questions:

* Is the broker up?
* Are topics receiving messages?
* Are partitions healthy?
* Is the JVM or request path under pressure?

Application metrics come from CPEmon services and answer business-flow
questions:

* Did `acs-ingest` publish events?
* Did `cpemon-writer` consume and commit offsets?
* Are retries or dead-letter events increasing?

The Kafka chart now enables JMX exporter metrics and creates a ServiceMonitor
with `release: kps` in the `monitoring` namespace. That lets the shared
kube-prometheus-stack discover Kafka broker metrics while CPEmon services keep
their own producer and consumer metrics.

## CCPU-108 Learning Notes: Writer Consumer Metrics

Writer Consumer Metrics explain the second half of the Kafka path: after
`acs-ingest` produces normalized events, `cpemon-writer` must consume, process,
write to the database, commit offsets, retry transient failures, and dead-letter
poison messages.

The metrics are split into:

* consumer progress: consumed offset, committed offset, message age, reader lag
* processing outcomes: success, retry, error, dead-letter
* retry/dead-letter detail: bounded `kind` labels such as `poison_message`

This is the at-least-once processing story. Consumer lag, consumed offset, and
committed offset show whether the writer is keeping up and whether it is safe to
advance Kafka offsets. The writer should commit offsets only after the event has
been processed durably. Metrics make that visible.

## CCPU-109 Learning Notes: API HTTP Metrics

`cpemon-api` uses RED metrics:

* Rate: `cpemon_api_http_requests_total`
* Errors: the same counter filtered by `code=~"4..|5.."`
* Duration: `cpemon_api_http_request_duration_seconds`

The route label uses the Gin route template, for example `/api/cpe/:sn`, instead
of the concrete request path. That means `/api/cpe/CPE-001` and
`/api/cpe/CPE-002` share one time series instead of creating one series per
device.

The older `cpemon_api_requests_total{code}` metric remains for compatibility,
but the route-aware RED metrics are the better dashboard source.

## Validation

```powershell
make monitoring-gitops-check
make cpemon-servicemonitor-check
make acs-ingest-ingestion-metrics-check
make kafka-metrics-boundary-check
make cpemon-writer-observability-story12-check
make cpemon-api-http-metrics-check
make monitoring-template
```

Live validation:

```powershell
kubectl get application monitoring-dev -n argocd
kubectl get pods,svc -n monitoring
kubectl get servicemonitor -A
kubectl get prometheusrule -A
```
