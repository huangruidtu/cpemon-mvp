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

## CCPU-110 Learning Notes: Grafana Pipeline Dashboard

The Grafana pipeline dashboard is the visual story of the migration. It should
show the path from ACS webhook intake to Kafka, writer processing, dead-letter
handling, and API health.

The important design principle is that each panel maps to a pipeline question:

* Is traffic entering `acs-ingest`?
* Are events being accepted, rejected, or failing downstream?
* Is Kafka scrapeable and healthy from Prometheus?
* Is `cpemon-writer` processing, retrying, or dead-lettering events?
* Is `cpemon-api` healthy by RED metrics?

## CCPU-182 Learning Notes: API Health Dashboard

The API health dashboard is focused on user-facing reliability. It uses the same
RED metrics as `CCPU-109`, but it presents them as a dedicated operational view:

* request rate by route and status
* 5xx error rate by route
* p95 latency by route
* scrape health for `cpemon-api`

The dashboard is separate from the pipeline dashboard because the API can have a
user-facing incident even when the ingestion pipeline is healthy. Separating the
views makes the operating model easier to explain in an interview.

## CCPU-111 Learning Notes: Alert Baseline

Alerts differ from dashboards. A dashboard can contain many useful signals; an
alert should be actionable and tied to an operator response.

The baseline alerts cover:

* service scrape failure
* API 5xx rate
* API p95 latency
* ACS ingest errors
* writer dead-letter activity
* Kafka metrics scrape failure

The expressions use implemented metrics from this story rather than future or
external-only metrics. This keeps the alert baseline honest and testable.

## CCPU-183 Learning Notes: OpenTelemetry Collector Boundary

The Collector is telemetry pipeline infrastructure. Applications emit telemetry;
the Collector receives, batches, limits, and exports it to a backend such as
Tempo or Jaeger.

This story stages a minimal Collector boundary with OTLP gRPC/HTTP receivers,
`memory_limiter`, `batch`, and a `debug` exporter. The debug exporter makes the
first deployment testable before a trace backend is live.

## CCPU-184 Learning Notes: Minimal Tracing

Minimal tracing starts with context propagation. `cpemon-api` now accepts an
incoming W3C `traceparent` header or `X-Trace-Id`, creates one when absent, and
returns both headers to the caller.

This is not a full tracing backend yet. It is the service-path contract that
lets later work attach spans and exports without changing every handler again.

## CCPU-185 Learning Notes: trace_id structured logs

`trace_id` is the join key between request logs and traces. `cpemon-api` now
logs one structured HTTP request event after each handler finishes:

```text
event=http_request service=cpemon-api trace_id=<trace-id> method=<method> route=<route> code=<status> duration_ms=<duration>
```

The incident workflow becomes:

```text
metric symptom -> dashboard -> trace_id -> logs -> trace path
```

This is interview-important because it shows the difference between telemetry
types:

* metrics answer "how many, how slow, how often?"
* logs answer "what happened for this concrete request?"
* traces answer "where did this request spend time across boundaries?"

The structured request log avoids device serial numbers and raw payload data.
Those details can appear in carefully scoped application logs when needed, but
they should not become the default correlation fields for every request.

## CCPU-186 Learning Notes: Tempo trace export

Tempo is the first trace backend for this story. The decision is intentional:
Prometheus and Grafana already anchor the metrics and dashboard experience, so
Tempo keeps traces in the same Grafana-centered operating model.

The export path is:

```text
application OTLP -> OpenTelemetry Collector -> Tempo -> Grafana
```

`k8s/observability/tempo.yaml` stages a minimal single-pod Tempo deployment for
the dev learning environment. `k8s/observability/otel-collector.yaml` exports
traces to `tempo.observability.svc.cluster.local:4317` while keeping the
`debug` exporter enabled for early troubleshooting.

Interview framing:

* Prometheus stores aggregated time series; it does not store request paths.
* Tempo stores traces, which are per-request timing graphs.
* Logs include `trace_id` so a concrete request can be found in both logs and
  Tempo.
* Jaeger would also work, but Tempo fits better when Grafana is already the
  primary UI.

## CCPU-187 Learning Notes: End-to-end validation

End-to-end observability validation should not be a vague statement like "we
have monitoring." It should prove each layer of the evidence chain.

| Proof type | Meaning |
| --- | --- |
| Repository proof | Manifests, dashboards, rules, scripts, and docs are present and internally consistent. |
| Render proof | Helm and YAML artifacts render or lint locally. |
| Live cluster proof | A reachable cluster accepts resources and emits real metrics, logs, alerts, and traces. |

For this environment, `make observability-e2e-check` is the repository proof. It
runs the Story 12 validation scripts for GitOps, ServiceMonitor, application
metrics, Kafka metrics, dashboards, alerts, Collector, tracing, log
correlation, and Tempo export.

The live cluster proof remains a separate operator workflow because the local
kubeconfig currently points at `localhost:8080`. That distinction is important
in interviews: a good engineer explains what has been proven and what still
requires a live system.

Interview narrative:

```text
I can prove observability in layers. First, repo checks prove the manifests,
queries, alerts, and runbooks are present. Then Helm lint/render checks prove
the app observability templates are valid. Finally, in a live cluster, I prove
Prometheus scrape targets, Grafana panels, alert rules, structured logs, and
Tempo trace lookup with a real trace_id.
```

## Story 12 Final Interview Narrative

Story 12 turns CPEmon observability into a platform-grade operating model:
metrics, logs, traces, dashboards, and alerts each have a clear job.

The concise interview answer is:

> I separated platform monitoring from application telemetry. Argo CD manages
> the shared monitoring stack, while CPEmon exposes low-cardinality metrics,
> ServiceMonitors, dashboards, alerts, structured logs with `trace_id`, and an
> OpenTelemetry path into Tempo. I validated the work in layers: repository
> checks, Helm/render checks, and live-cluster checks for Prometheus, Grafana,
> Alertmanager, logs, and traces.

The strongest proof points are:

* ServiceMonitor templates connect CPEmon services to Prometheus.
* ACS ingest, writer, API, and Kafka boundaries expose different signal types.
* Grafana has one dashboard for event pipeline health and one for API health.
* PrometheusRule alerts are action-oriented and link back to the runbook.
* `trace_id` connects logs and Tempo traces.
* The ADR records why Tempo was chosen and where repository validation stops.

## Validation

```powershell
make monitoring-gitops-check
make cpemon-servicemonitor-check
make acs-ingest-ingestion-metrics-check
make kafka-metrics-boundary-check
make cpemon-writer-observability-story12-check
make cpemon-api-http-metrics-check
make grafana-pipeline-dashboard-check
make grafana-api-health-dashboard-check
make prometheus-alert-baseline-check
make otel-collector-boundary-check
make minimal-tracing-check
make trace-id-structured-logs-check
make trace-export-boundary-check
make observability-e2e-check
make monitoring-observability-final-docs-check
make monitoring-template
```

Live validation:

```powershell
kubectl get application monitoring-dev -n argocd
kubectl get pods,svc -n monitoring
kubectl get servicemonitor -A
kubectl get prometheusrule -A
```
