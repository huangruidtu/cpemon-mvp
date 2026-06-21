# cpemon-writer Kafka Consumer Operations Runbook

## Purpose

Use this as the top-level operations guide for the `cpemon-writer` Kafka
consumer migration.

Covered task:

- `CCPU-173`: Document cpemon-writer Kafka consumer runbook and migration
  decision.

## Quick Mental Model

```text
acs-ingest
  -> Kafka topics
  -> cpemon-writer consumer group
  -> MySQL cpe_status / cpe_status_history
  -> cpemon-api
```

The writer targets at-least-once processing. It commits Kafka offsets only
after successful MySQL processing or successful dead-letter publication.

## Configuration

Required environment variables:

| Variable | Meaning |
| --- | --- |
| `KAFKA_CONSUMER_ENABLED` | Feature flag for the writer Kafka consumer. |
| `KAFKA_BOOTSTRAP_SERVERS` | Kafka bootstrap service. |
| `KAFKA_CONSUMER_GROUP_ID` | Consumer group id, expected `cpemon-writer`. |
| `KAFKA_TOPIC_DEVICE_HEARTBEAT` | Heartbeat topic. |
| `KAFKA_TOPIC_WAN_STATUS` | WAN status topic. |
| `KAFKA_TOPIC_DEADLETTER` | Dead-letter topic. |
| `KAFKA_CONSUMER_READ_TIMEOUT` | Fetch timeout. |
| `KAFKA_CONSUMER_COMMIT_TIMEOUT` | Offset commit timeout. |
| `KAFKA_CONSUMER_MAX_RETRIES` | Retry count before dead-letter. |
| `KAFKA_CONSUMER_RETRY_BACKOFF` | Delay between retries. |

Check rendered pod env:

```powershell
kubectl exec -n cpemon deploy/cpemon-writer -- printenv |
  Select-String -Pattern "KAFKA_CONSUMER|KAFKA_TOPIC|KAFKA_BOOTSTRAP"
```

## Enable

Enable with Helm values:

```yaml
appConfig:
  kafkaConsumerEnabled: true
  kafkaConsumerGroupId: cpemon-writer
```

Expected startup log:

```text
event=writer_kafka_consumer result=start group=cpemon-writer
```

## Disable / Rollback

Set:

```yaml
appConfig:
  kafkaConsumerEnabled: false
```

Then redeploy `cpemon-writer`.

Rollback expectation:

* Kafka consumer loop no longer starts.
* Existing MySQL queue baseline remains available.
* Kafka offsets do not advance for the disabled consumer group.

## Core Checks

Consumer group:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-consumer-groups.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --describe `
  --group cpemon-writer
```

Writer logs:

```powershell
kubectl logs -n cpemon deploy/cpemon-writer --tail=200 |
  Select-String -Pattern "writer_kafka"
```

Metrics:

```powershell
kubectl port-forward -n cpemon deploy/cpemon-writer 9100:9100
Invoke-WebRequest http://127.0.0.1:9100/metrics |
  Select-Object -ExpandProperty Content |
  Select-String -Pattern "cpemon_writer_kafka"
```

## Troubleshooting

No messages processed:

1. Confirm `KAFKA_CONSUMER_ENABLED=true`.
2. Confirm topics exist.
3. Confirm `event=writer_kafka_consumer result=start`.
4. Confirm the consumer group exists.
5. Confirm messages were produced to heartbeat or WAN status topics.

Lag grows:

1. Inspect `kafka-consumer-groups.sh --describe`.
2. Check `cpemon_writer_kafka_processing_retries_total`.
3. Check MySQL connectivity.
4. Check dead-letter metrics.
5. Check partition count vs writer replica count.

Decode failures:

1. Look for `kind=poison_message`.
2. Inspect `event=writer_kafka_deadletter result=success`.
3. Consume from `cpemon.deadletter.v1`.
4. Compare producer schema with consumer validation rules.

DB errors:

1. Look for `result=retry kind=retriable_error`.
2. Check `DB_DSN` and MySQL service/endpoints.
3. Check `cpe_status` and `cpe_status_history` schema.
4. Use `ops/runbooks/cpemon-writer-db-write-path.md`.

Duplicate processing:

1. Remember the design is at-least-once.
2. Check offset commit errors.
3. Confirm idempotent upserts are preserving latest state.
4. Inspect history rows by `(sn, event_ts)`.

Dead-letter publish errors:

1. Look for `event=writer_kafka_deadletter result=error`.
2. Confirm `cpemon.deadletter.v1` exists.
3. Confirm the writer can reach Kafka.
4. Do not commit the original message until dead-letter publish succeeds.

## Validation Runbooks

Use these in order:

1. `ops/runbooks/cpemon-writer-kafka-consumer-group.md`
2. `ops/runbooks/cpemon-writer-kafka-consumer-lag.md`
3. `ops/runbooks/cpemon-writer-kafka-to-db-validation.md`
4. `ops/runbooks/cpemon-api-kafka-updated-status-validation.md`

## Repository Check

```powershell
make cpemon-writer-kafka-consumer-operations-check
```

This validates the runbook and migration decision docs. It does not prove live
cluster behavior.

## Interview Summary

I would describe the migration as a staged replacement of database polling with
Kafka consumption. The important reliability choices are feature-flag rollout,
stable consumer group id, explicit offset commits after MySQL success,
idempotent writes, bounded retries, dead-letter handling, low-cardinality
metrics, and a rollback path that disables the consumer without reverting code.
