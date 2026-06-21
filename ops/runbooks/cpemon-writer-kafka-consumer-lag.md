# cpemon-writer Kafka Consumer Lag Runbook

## Purpose

Use this runbook when `cpemon-writer` may be falling behind Kafka.

Covered task:

- `CCPU-93`: Add consumer lag metrics.

## Mental Model

Kafka consumer lag is the distance between the latest broker offset and the
consumer group's committed offset:

```text
lag = log-end-offset - current committed offset
```

For `cpemon-writer`, committed offsets should advance only after the message is
validated, written to MySQL, or safely moved to the dead-letter topic.

## Application Metrics

`cpemon-writer` exposes these low-cardinality Prometheus metrics:

| Metric | Labels | Meaning |
| --- | --- | --- |
| `cpemon_writer_kafka_consumer_last_consumed_offset` | `group`, `topic`, `partition` | Last offset fetched by the writer consumer. |
| `cpemon_writer_kafka_consumer_last_committed_offset` | `group`, `topic`, `partition` | Last offset committed after successful processing. |
| `cpemon_writer_kafka_consumer_message_age_seconds` | `group`, `topic`, `partition` | Age of the last consumed message. |
| `cpemon_writer_kafka_consumer_reader_lag_messages` | `group`, `topic`, `partition` | Reader-reported lag when the client can provide it. |

The labels intentionally avoid high-cardinality values such as device id,
serial number, message key, or error text.

Important boundary:

`kafka-go` does not always expose true lag from the reader in consumer group
mode. Treat `cpemon_writer_kafka_consumer_reader_lag_messages` as a useful
adapter signal when present, not as the only source of truth. The broker-side
consumer group command remains the authoritative lag check.

## Inspect Metrics

Port-forward writer metrics:

```powershell
kubectl port-forward -n cpemon deploy/cpemon-writer 9100:9100
```

Query local metrics:

```powershell
Invoke-WebRequest http://127.0.0.1:9100/metrics |
  Select-Object -ExpandProperty Content |
  Select-String -Pattern "cpemon_writer_kafka_consumer"
```

Useful PromQL examples:

```promql
cpemon_writer_kafka_consumer_message_age_seconds{group="cpemon-writer"}
```

```promql
cpemon_writer_kafka_consumer_last_consumed_offset{group="cpemon-writer"}
-
cpemon_writer_kafka_consumer_last_committed_offset{group="cpemon-writer"}
```

The offset difference above is an application-side processing gap, not broker
lag. It helps identify messages fetched but not committed by this process.

## Authoritative Broker Lag

Inspect the Kafka consumer group:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-consumer-groups.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --describe `
  --group cpemon-writer
```

Important columns:

| Column | Meaning |
| --- | --- |
| `TOPIC` | Topic being consumed. |
| `PARTITION` | Partition number. |
| `CURRENT-OFFSET` | Consumer group's committed offset. |
| `LOG-END-OFFSET` | Latest broker offset. |
| `LAG` | `LOG-END-OFFSET - CURRENT-OFFSET`. |
| `CONSUMER-ID` | Current group member processing the partition. |

## Troubleshooting Growing Lag

Check these in order:

1. Is `cpemon-writer` running and healthy?

   ```powershell
   kubectl get pods -n cpemon -l app=cpemon-writer
   kubectl logs -n cpemon deploy/cpemon-writer --tail=200
   ```

2. Are processing errors increasing?

   ```promql
   rate(cpemon_writer_events_failed_total[5m])
   ```

3. Are messages being consumed but not committed?

   Compare `last_consumed_offset` and `last_committed_offset` by topic and
   partition.

4. Is MySQL slow or unavailable?

   Look for DB write failures and retry/dead-letter activity in writer logs.

5. Is one poison message blocking progress?

   Check dead-letter topic traffic and writer logs for `poison_message`.

6. Is the consumer group rebalancing repeatedly?

   Use `kafka-consumer-groups.sh --describe` and pod logs to look for unstable
   group membership.

7. Is the workload under-partitioned?

   Scaling writer replicas beyond topic partition count will not increase
   parallelism for that topic.

## Interview Summary

Lag is not just "the consumer is slow." It is the distance between broker
production and consumer group commits. In this project, application metrics show
the writer's local consume/commit progress and message age, while the Kafka
consumer group command shows authoritative broker lag. The labels are limited
to group, topic, and partition so the metrics remain operationally safe.
