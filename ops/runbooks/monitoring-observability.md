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

## CPEmon Helm ServiceMonitor

The CPEmon Helm chart renders one ServiceMonitor named `cpemon-services` when
`serviceMonitor.enabled=true`.

The dev values enable it because the `monitoring-dev` Application installs
kube-prometheus-stack and its CRDs first.

```powershell
make cpemon-servicemonitor-check
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

Expected contract:

| Contract | Expected value |
| --- | --- |
| ServiceMonitor namespace | `monitoring` |
| Prometheus release selector | `release: kps` |
| Workload namespace selector | `cpemon` |
| Service selector | `app in (cpemon-api, acs-ingest, cpemon-writer)` |
| Endpoint port | `metrics` |
| Endpoint path | `/metrics` |

## ACS Ingestion Metrics

`acs-ingest` exposes entrance metrics before the pipeline reaches Kafka:

| Metric | Meaning |
| --- | --- |
| `acs_webhook_requests_total{code}` | Webhook request rate by final HTTP status code. |
| `acs_webhook_errors_total{reason}` | Validation, DB, and publish failures by bounded reason. |
| `acs_webhook_duration_seconds{code}` | Webhook handling latency by final HTTP status code. |
| `acs_webhook_payload_bytes` | Request payload size distribution. |
| `acs_ingest_events_total{result}` | Ingestion result: `queued`, `invalid`, `db_failed`, or `publish_failed`. |

These labels are intentionally low-cardinality. Device serial numbers belong in
structured logs and traces, not Prometheus labels.

Useful PromQL:

```promql
sum(rate(acs_webhook_requests_total[5m])) by (code)
sum(rate(acs_webhook_errors_total[5m])) by (reason)
histogram_quantile(0.95, sum(rate(acs_webhook_duration_seconds_bucket[5m])) by (le, code))
sum(rate(acs_ingest_events_total[5m])) by (result)
```

## Kafka Metrics Boundary

Kafka observability has two layers:

| Layer | Metrics | Owner |
| --- | --- | --- |
| Broker/platform | JMX exporter metrics such as broker health, request rate, topic state, partition state, and JVM pressure. | Kafka platform chart |
| Application pipeline | Producer publish totals/errors/duration and writer consumer offset/lag/processing metrics. | CPEmon services |

The Bitnami Kafka values now enable JMX metrics and a ServiceMonitor:

```yaml
metrics:
  jmx:
    enabled: true
  serviceMonitor:
    enabled: true
    namespace: monitoring
    labels:
      release: kps
```

Repository validation:

```powershell
make kafka-metrics-boundary-check
```

Live checks:

```powershell
kubectl get servicemonitor -n monitoring -l release=kps
kubectl get svc -n kafka | Select-String metrics
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090
```

Prometheus queries to try after sync:

```promql
up{namespace="kafka"}
kafka_server_brokertopicmetrics_messagesin_total
kafka_server_replicamanager_underreplicatedpartitions
```

## Writer Consumer Metrics

`cpemon-writer` exposes two categories of Kafka consumer metrics.

Offset and lag metrics:

| Metric | Meaning |
| --- | --- |
| `cpemon_writer_kafka_consumer_last_consumed_offset{group,topic,partition}` | Last offset fetched from Kafka. |
| `cpemon_writer_kafka_consumer_last_committed_offset{group,topic,partition}` | Last offset committed after successful processing. |
| `cpemon_writer_kafka_consumer_message_age_seconds{group,topic,partition}` | Age of the last consumed message. |
| `cpemon_writer_kafka_consumer_reader_lag_messages{group,topic,partition}` | kafka-go reader lag when available. |

Processing metrics:

| Metric | Meaning |
| --- | --- |
| `cpemon_writer_kafka_processing_events_total{topic,result,kind}` | Success, retry, error, and dead-letter outcomes. |
| `cpemon_writer_kafka_processing_retries_total{topic,kind}` | Retry volume by bounded failure kind. |
| `cpemon_writer_kafka_deadletters_total{topic,result,kind}` | Dead-letter publish outcomes. |
| `cpemon_writer_kafka_processing_duration_seconds{topic,result,kind}` | Processing latency by outcome. |

Useful PromQL:

```promql
sum(rate(cpemon_writer_kafka_processing_events_total[5m])) by (topic, result, kind)
sum(rate(cpemon_writer_kafka_processing_retries_total[5m])) by (topic, kind)
sum(rate(cpemon_writer_kafka_deadletters_total[5m])) by (topic, result, kind)
max(cpemon_writer_kafka_consumer_message_age_seconds) by (group, topic, partition)
```

For at-least-once processing, the key debugging relationship is consumed offset
versus committed offset. If consumed advances but committed stalls, the writer is
fetching messages but failing before durable completion.

## Interview Framing

The clean answer is:

> I managed monitoring as a platform add-on through Argo CD because Prometheus,
> Grafana, Alertmanager, CRDs, and operators are shared cluster capabilities.
> Applications expose metrics and define dashboards or alerts, but the platform
> owns the monitoring control plane. That separation prevents every service from
> installing its own Prometheus stack and gives the team one observable cluster
> contract.
