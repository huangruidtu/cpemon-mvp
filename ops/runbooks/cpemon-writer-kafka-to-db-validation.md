# cpemon-writer Kafka-to-DB Integration Validation

## Purpose

This runbook proves the live path:

```text
Kafka topic -> cpemon-writer Kafka consumer -> MySQL cpe_status / cpe_status_history
```

Unit tests prove routing, decoding, idempotent writes, retry, dead-letter, and
offset decisions without Kafka. This runbook proves the real broker-to-database
path when a Kubernetes cluster, Kafka release, and MySQL workload are available.

Covered task:

- `CCPU-94`: Add Kafka-to-DB integration validation.

## Preconditions

Required tools:

* `go`
* `helm`
* `kubectl`

Required platform state:

* Namespace `cpemon` exists.
* Namespace `kafka` exists.
* Kafka bootstrap service is reachable at
  `kafka.kafka.svc.cluster.local:9092`.
* Topics exist:
  * `cpemon.device.heartbeat.v1`
  * `cpemon.wan.status.v1`
  * `cpemon.deadletter.v1`
* MySQL is running and has the CPEmon schema.
* `cpemon-writer` can read `DB_DSN`.

Repository checks before live validation:

```powershell
go test ./...
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
make cpemon-writer-kafka-to-db-validation-check
```

## Enable The Writer Consumer

Render or deploy `cpemon-writer` with:

```yaml
appConfig:
  kafkaConsumerEnabled: true
  kafkaBootstrapServers: kafka.kafka.svc.cluster.local:9092
  kafkaConsumerGroupId: cpemon-writer
  kafkaTopicDeviceHeartbeat: cpemon.device.heartbeat.v1
  kafkaTopicWanStatus: cpemon.wan.status.v1
  kafkaTopicDeadletter: cpemon.deadletter.v1
  kafkaConsumerReadTimeout: 5s
  kafkaConsumerCommitTimeout: 5s
  kafkaConsumerMaxRetries: 3
  kafkaConsumerRetryBackoff: 1s
```

Expected pod environment:

```text
KAFKA_CONSUMER_ENABLED=true
KAFKA_BOOTSTRAP_SERVERS=kafka.kafka.svc.cluster.local:9092
KAFKA_CONSUMER_GROUP_ID=cpemon-writer
KAFKA_TOPIC_DEVICE_HEARTBEAT=cpemon.device.heartbeat.v1
KAFKA_TOPIC_WAN_STATUS=cpemon.wan.status.v1
KAFKA_TOPIC_DEADLETTER=cpemon.deadletter.v1
```

Confirm:

```powershell
kubectl exec -n cpemon deploy/cpemon-writer -- printenv |
  Select-String -Pattern "KAFKA_CONSUMER|KAFKA_TOPIC|KAFKA_BOOTSTRAP"
```

Expected startup log:

```text
event=writer_kafka_consumer result=start group=cpemon-writer
```

## Produce Heartbeat Event

Produce a heartbeat event into Kafka:

```powershell
$heartbeatLine = 'TEST-CPE-KAFKA-DB-001|{"schema_version":"v1","event_type":"device.heartbeat","source":"manual-validation","device_id":"TEST-CPE-KAFKA-DB-001","serial_number":"TEST-CPE-KAFKA-DB-001","event_ts":"2026-06-22T10:00:00Z","received_at":"2026-06-22T10:00:01Z","status":"online"}'

$heartbeatLine |
  kubectl exec -i -n kafka statefulset/kafka-controller -- kafka-console-producer.sh `
    --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
    --topic cpemon.device.heartbeat.v1 `
    --property parse.key=true `
    --property key.separator="|"
```

If your shell does not support here-strings with `kubectl exec`, use an
interactive producer and paste one line:

```text
TEST-CPE-KAFKA-DB-001|{"schema_version":"v1","event_type":"device.heartbeat","source":"manual-validation","device_id":"TEST-CPE-KAFKA-DB-001","serial_number":"TEST-CPE-KAFKA-DB-001","event_ts":"2026-06-22T10:00:00Z","received_at":"2026-06-22T10:00:01Z","status":"online"}
```

Expected writer log:

```text
event=writer_kafka_process result=success topic=cpemon.device.heartbeat.v1 key=TEST-CPE-KAFKA-DB-001
```

## Produce WAN Status Event

Produce a WAN status event:

```text
TEST-CPE-KAFKA-DB-001|{"schema_version":"v1","event_type":"wan.status","source":"manual-validation","device_id":"TEST-CPE-KAFKA-DB-001","serial_number":"TEST-CPE-KAFKA-DB-001","event_ts":"2026-06-22T10:05:00Z","received_at":"2026-06-22T10:05:01Z","wan_status":"up","wan_ip":"10.0.0.13","sw_version":"v1.0-demo"}
```

Expected writer log:

```text
event=writer_kafka_process result=success topic=cpemon.wan.status.v1 key=TEST-CPE-KAFKA-DB-001
```

## Verify MySQL State

Run SQL inside the MySQL pod or through any approved DB client:

```sql
SELECT sn, last_seen, wan_ip, sw_version
FROM cpe_status
WHERE sn = 'TEST-CPE-KAFKA-DB-001';
```

Expected current row:

| Column | Expected |
| --- | --- |
| `sn` | `TEST-CPE-KAFKA-DB-001` |
| `last_seen` | `2026-06-22 10:05:00` or later event timestamp representation |
| `wan_ip` | `10.0.0.13` |
| `sw_version` | `v1.0-demo` |

Check history:

```sql
SELECT sn, event_ts, last_seen, wan_ip, sw_version
FROM cpe_status_history
WHERE sn = 'TEST-CPE-KAFKA-DB-001'
ORDER BY event_ts;
```

Expected:

* one heartbeat history row for `2026-06-22T10:00:00Z`
* one WAN status history row for `2026-06-22T10:05:00Z`

## Verify Offsets And Metrics

Inspect consumer group lag:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-consumer-groups.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --describe `
  --group cpemon-writer
```

Expected:

* `CURRENT-OFFSET` advances for heartbeat and WAN status partitions.
* `LAG` returns to zero after messages are processed.

Inspect metrics:

```powershell
kubectl port-forward -n cpemon deploy/cpemon-writer 9100:9100
Invoke-WebRequest http://127.0.0.1:9100/metrics |
  Select-Object -ExpandProperty Content |
  Select-String -Pattern "cpemon_writer_kafka"
```

Expected metric families:

```text
cpemon_writer_kafka_consumer_last_consumed_offset
cpemon_writer_kafka_consumer_last_committed_offset
cpemon_writer_kafka_processing_events_total
cpemon_writer_kafka_processing_duration_seconds
```

## Failure Drill

If MySQL does not update:

1. Confirm `KAFKA_CONSUMER_ENABLED=true`.
2. Confirm `event=writer_kafka_consumer result=start` appears in writer logs.
3. Confirm the topic received the message with `kafka-console-consumer.sh`.
4. Check writer logs for `event=writer_kafka_process result=retry`.
5. Check writer logs for `event=writer_kafka_deadletter`.
6. Inspect `cpemon.deadletter.v1` for poison messages.
7. Check `kafka-consumer-groups.sh --describe --group cpemon-writer`.
8. Check MySQL connectivity and schema with the DB runbook.

## Validation Boundary

Repository validation:

```powershell
make cpemon-writer-kafka-to-db-validation-check
```

This validates the runbook, code wiring, config keys, docs, and commands. It
does not prove live broker-to-DB behavior. Live proof requires running the
produce and SQL verification steps above against a real cluster with Kafka,
`cpemon-writer`, and MySQL running.

## Interview Summary

Unit tests prove deterministic consumer decisions without Kafka. Integration
validation proves the real system boundary: Kafka stores a message,
`cpemon-writer` consumes it in the `cpemon-writer` group, the handler writes
MySQL, the adapter commits the offset, and the API/database state reflects the
event. Keeping those validation layers separate makes failures easier to debug.
