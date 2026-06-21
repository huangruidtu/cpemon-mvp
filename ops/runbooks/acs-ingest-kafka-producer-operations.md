# acs-ingest Kafka Producer Operations Runbook

## Purpose

Use this runbook when `acs-ingest` Kafka publishing is enabled and heartbeat or
WAN status events are not reaching Kafka as expected.

## Fast Triage

Check the application state:

```powershell
kubectl get pods,svc -n cpemon
kubectl logs -n cpemon deploy/acs-ingest --tail=120
kubectl describe deploy -n cpemon acs-ingest
```

Check Kafka state:

```powershell
kubectl get pods,svc,statefulset -n kafka
kubectl exec -n kafka statefulset/kafka-controller -- kafka-topics.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --list
```

Check producer metrics:

```powershell
kubectl port-forward -n cpemon svc/acs-ingest 9100:9100
Invoke-WebRequest http://127.0.0.1:9100/metrics | Select-Object -ExpandProperty Content
```

Key metrics:

```text
acs_ingest_kafka_producer_publishes_total
acs_ingest_kafka_producer_publish_errors_total
acs_ingest_kafka_producer_publish_duration_seconds
```

## Incident Patterns

### Kafka unavailable

Symptoms:

* `event=kafka_publish result=error`
* `kind=writer_error` or `kind=timeout`
* Rising `acs_ingest_kafka_producer_publish_errors_total`

Checks:

```powershell
kubectl get pods -n kafka
kubectl get svc -n kafka
kubectl exec -n cpemon deploy/acs-ingest -- nslookup kafka.kafka.svc.cluster.local
```

Response:

* Confirm Kafka pods are running.
* Confirm service DNS resolves from `cpemon`.
* Confirm network policy allows egress from `cpemon` to `kafka`.

### Topic missing

Symptoms:

* Publish errors for `cpemon.device.heartbeat.v1` or `cpemon.wan.status.v1`.
* Kafka logs or writer errors mention unknown topic/partition.

Checks:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-topics.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --describe `
  --topic cpemon.device.heartbeat.v1
```

Response:

* Compare topic names with Story 8 topic config.
* Create or repair the missing topic through the Kafka platform runbook.

### Serialization failure

Symptoms:

* `kind=serialization_error`
* No writer attempts.

Response:

* Inspect mapper tests and event schema changes.
* Do not retry blindly; fix the event contract or mapper.

### Timeout

Symptoms:

* `kind=timeout`
* Publish duration close to `KAFKA_PRODUCER_TIMEOUT`.

Response:

* Check broker health and latency.
* Confirm `KAFKA_PRODUCER_TIMEOUT` is reasonable for the environment.
* Compare latency histogram buckets before increasing timeout.

### Bad key or invalid event

Symptoms:

* `kind=invalid_event`
* Empty topic or key in error context.

Response:

* Check `sn` in the incoming ACS payload.
* Validate mapper behavior with unit tests.
* Reject or fix the upstream payload source.

### Oversized event

Symptoms:

* Writer errors mention message size or request size.

Response:

* Do not log the full payload.
* Check payload size at the source.
* Decide whether to trim optional fields, move large payloads to object storage,
  or raise broker/client limits.

## Manual Consume Check

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-console-consumer.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --topic cpemon.device.heartbeat.v1 `
  --from-beginning `
  --property print.key=true `
  --property key.separator="|" `
  --max-messages 1
```

Use `ops/runbooks/acs-ingest-kafka-producer-validation.md` for the full
webhook-to-Kafka validation path.

## Rollback Boundary

Set:

```text
KAFKA_PRODUCER_ENABLED=false
```

This returns `acs-ingest` to enqueue-only behavior while keeping the code and
configuration in place for a later re-enable.
