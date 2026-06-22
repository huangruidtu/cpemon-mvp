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
