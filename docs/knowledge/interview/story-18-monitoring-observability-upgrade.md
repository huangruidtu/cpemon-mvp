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

## Q7: What acs-ingest metrics did you add?

I added request count, error count, duration histogram, payload-size histogram,
and ingestion-result count. Together they show whether webhooks are arriving,
whether they are valid, how long intake takes, whether payload size is unusual,
and whether failures happen before or after the database/Kafka handoff.

## Q8: Why are the labels low-cardinality?

Prometheus labels create time series. If we label metrics by device serial
number or raw event key, every device creates new series and the monitoring
system becomes expensive and noisy. I keep labels like `code`, `reason`, and
`result` in metrics, and put device-specific identifiers in logs and traces.

## Q9: How do you explain broker metrics versus application metrics?

Broker metrics versus application metrics is one of the most important
observability boundaries in this story.

Broker metrics come from Kafka/JMX and describe the platform: broker up status,
request rate, topic throughput, partitions, JVM pressure, and replication health.
Application metrics come from CPEmon code and describe the business pipeline:
producer publish success/failure/duration, consumer offset progress, retry
counts, dead-letter counts, and database write outcomes.

In an incident, I use both. Broker metrics tell me whether Kafka is healthy.
Application metrics tell me whether CPEmon is using Kafka correctly.

## Q10: How do writer metrics support at-least-once processing?

At-least-once means the consumer should not commit an offset until processing is
durably complete. The writer exposes consumed offset, committed offset, message
age, reader lag, processing outcome counters, retry counters, dead-letter
counters, and processing latency. If consumed offset moves but committed offset
stalls, the writer is fetching messages but failing before completion.

## Q11: Why does dead-letter observability matter?

Dead-letter metrics separate poison-message failures from transient operational
failures. Without them, a bad payload and a temporary database outage can look
the same. With bounded labels like `topic`, `result`, and `kind`, the team can
alert on increasing dead-letter rates without creating high-cardinality metrics.

## Q12: What are RED metrics?

RED metrics are Rate, Errors, and Duration. For `cpemon-api`, rate and errors
come from `cpemon_api_http_requests_total{method,route,code}`, and duration
comes from `cpemon_api_http_request_duration_seconds{method,route,code}`.

## Q13: Why use a route template label?

The route template label keeps metrics low-cardinality. `/api/cpe/:sn` is safe;
`/api/cpe/CPE-001` as a label value is not, because every device would create a
new time series.

## Q14: How does the dashboard tell the event-flow story?

The dashboard tells the event-flow story by following the request path: ACS
webhooks arrive, ingestion accepts or rejects events, Kafka exposes broker
health, the writer consumes/processes/retries/dead-letters events, and the API
serves read traffic with RED metrics. That order makes troubleshooting faster
because each panel corresponds to one pipeline boundary.

## Q15: Why create a separate API reliability dashboard?

An API reliability dashboard answers a narrower question than a pipeline
dashboard: are user-facing API routes fast, successful, and scrapeable? The
pipeline dashboard explains event flow, while the API reliability dashboard
focuses on RED metrics for `cpemon-api`: request rate, 5xx errors, p95 latency,
and service up status.

## Q16: How do alerts differ from dashboards?

Dashboards are for exploration and diagnosis; alerts are for action. I kept the
baseline alerts focused on conditions that should trigger an operator response:
service scrape failure, API 5xx rate, API latency, ingest errors, writer
dead-letter activity, and Kafka metrics scrape failure. Each alert has bounded
labels and a runbook pointer.

## Q17: How do you explain the Collector as telemetry pipeline infrastructure?

The application should not know every backend detail. It emits telemetry through
OTLP, and the OpenTelemetry Collector receives, batches, limits, and exports
that data. That gives the platform one place to change exporters, sampling,
resource attributes, and backend endpoints without rewriting every service.

## Q18: How do you explain traces as latency path evidence?

Metrics tell me that something is slow or failing. Traces show the path of one
request through service boundaries. The first step is propagating a trace
context such as W3C `traceparent`; then spans and exporters can attach detailed
timing evidence to that same trace.

## Q19: Why put trace_id into structured logs?

`trace_id` is the practical join key during an incident. A dashboard can show
that `/api/cpe/:sn` is slow, but a structured log with `trace_id`, route,
status, and duration lets me find one concrete request. Then I can search the
trace backend for the same `trace_id` and inspect where time was spent.

I keep this field in logs because logs are usually the fastest evidence source
when an incident starts. I do not put device serial numbers or payload values in
Prometheus labels, and I avoid putting raw payload data in shared request logs.
That keeps telemetry useful without creating high-cardinality or privacy risk.

## Q20: Why choose Tempo before Jaeger here?

I chose Tempo first because the story is already Grafana-centered: Prometheus
for metrics, Grafana dashboards for visualization, and Tempo for traces. That
creates one coherent operator workflow in Grafana.

Jaeger is a strong tracing backend too, especially for standalone trace
exploration. For this project, Tempo is the cleaner first choice because it
integrates naturally with Grafana and works well when logs carry `trace_id`.

## Q21: How is Tempo different from Prometheus?

Prometheus stores aggregated time series such as request counts, error rates,
and latency histograms. Tempo stores traces, which represent individual request
paths and span timings. In an incident, Prometheus tells me that latency is
high; Tempo helps me inspect one slow request and see where the time went.

## Q22: How do you prove observability end to end?

End-to-end validation has three layers: Repository proof, Render proof, and
Live cluster proof.

I prove it in layers. Repository proof checks that manifests, dashboards,
alerts, scripts, and docs exist and are internally consistent. Render proof
checks Helm lint or template output. Live cluster proof checks that Prometheus
targets are up, dashboards show data, alerts exist, logs contain `trace_id`,
and Tempo can find a trace by that same ID.

That distinction matters because a repo check is not the same as a live
Prometheus scrape. In this project I added `make observability-e2e-check` for
the repository proof, and the runbook lists the live `kubectl`, Grafana,
Prometheus, and Tempo checks needed once the cluster is reachable.

## Q23: What would you show in an interview demo?

I would show the pipeline dashboard, API health dashboard, Prometheus targets,
PrometheusRule baseline, one structured API request log with `trace_id`, and
the matching trace lookup in Tempo. Then I would explain the troubleshooting
path: alert or dashboard symptom, route or service boundary, request log,
`trace_id`, trace backend, and finally the specific failing dependency or code
path.

## Q24: What is the final Story 12 interview summary?

I upgraded CPEmon observability from isolated health checks into a layered
platform model. Argo CD manages the shared monitoring stack. CPEmon exposes
ServiceMonitors, low-cardinality metrics, Grafana dashboards, PrometheusRule
alerts, structured logs with `trace_id`, and an OpenTelemetry Collector path to
Tempo.

The key design principle is that metrics, logs, traces, dashboards, and alerts
are different tools. Metrics tell me rates, errors, durations, lag, retries,
and dead letters. Logs tell me what happened for one concrete request or event.
Traces show the request path. Dashboards support exploration. Alerts page only
for actionable conditions.

## Q25: What mistakes did you deliberately avoid?

I avoided putting device serial numbers or raw payload values into Prometheus
labels, because that would create high cardinality. I avoided claiming live
cluster proof when the local kubeconfig could not reach a cluster. I avoided
making every app install its own monitoring stack. I also avoided treating a
dashboard as an alert; dashboards help diagnosis, while alerts need ownership,
thresholds, and a runbook.
