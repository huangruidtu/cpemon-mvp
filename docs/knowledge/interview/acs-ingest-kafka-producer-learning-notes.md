# acs-ingest Kafka Producer Learning Notes

Use this as the quick interview review sheet for Story 15.

## 60-Second Story

CPEmon originally accepted ACS webhook events and stored them in a database
queue. That was durable, but it coupled downstream processing to database
polling. I introduced a Kafka producer path in `acs-ingest` so the service can
publish normalized device events while preserving the existing intake behavior.

I started with event contracts for heartbeat and WAN status, then added a small
`EventPublisher` interface so the handler does not depend directly on Kafka.
The concrete producer uses `segmentio/kafka-go`, publishes JSON events with the
device serial number as the key, and is enabled by `KAFKA_PRODUCER_ENABLED`.

I added retry/error handling, producer metrics, structured logs, unit tests with
fake publishers and fake writers, and runbooks for live validation and
operations. The tradeoff is at-least-once delivery, so consumers must be
idempotent.

## Mental Model

```text
ACS webhook
  -> acs-ingest validation
  -> durable ingest_events write
  -> normalized heartbeat/WAN event
  -> EventPublisher
  -> KafkaProducer
  -> Kafka topic keyed by device identity
```

## Concepts

Producer:
The application component that writes events to Kafka. In this project,
`KafkaProducer` is hidden behind `EventPublisher`.

Topic:
The named Kafka stream. CPEmon uses `cpemon.device.heartbeat.v1` and
`cpemon.wan.status.v1`.

Partition key:
The key used to route messages. CPEmon uses stable device identity, currently
the ACS serial number, so events for the same device route consistently.

Serialization:
The normalized Go event structs are marshaled to JSON. Raw ACS payloads are not
published directly because that would leak source-specific shape to consumers.

Retry:
Writer errors are retried with bounded attempts. Invalid events and JSON
serialization failures fail fast.

Timeout:
Each write attempt uses `KAFKA_PRODUCER_TIMEOUT`. Timeout errors are classified
and surfaced with topic, key, and attempt count.

At-least-once delivery:
Retries can create duplicates if Kafka accepted a write but the client saw an
ambiguous error. Consumers must be idempotent.

Observability:
Metrics show rate, errors, and latency. Logs show topic, key, attempts,
duration, and error kind without dumping payloads.

## Strong Q&A

### Why add Kafka to `acs-ingest`?

To decouple ingestion from downstream processing. The database remains the
durable intake record, while Kafka gives downstream consumers a normalized,
subscribeable event stream.

### Why not publish raw ACS payloads?

Raw payloads couple consumers to the ACS webhook shape. Normalized CPEmon
events give stable field names, topic names, schema versions, event timestamps,
and keys.

### Why introduce `EventPublisher`?

It keeps business flow independent from the Kafka client. The handler can be
tested with a fake publisher, and the concrete producer can change later.

### Why publish after writing to the database?

The database write preserves the existing durable intake path. Publishing after
that means Kafka is added as a downstream handoff rather than replacing the
first reliable record.

### What is the key?

The device serial number, exposed as `device_id`. It keeps partition routing
consistent for a device.

### What happens if WAN fields are missing?

The service still publishes heartbeat and skips WAN status. WAN status is a
separate event family and should only exist when the payload carries WAN data.

### Which errors are retried?

Writer/transport errors are retried because they may be transient. Invalid
event shape, missing key/topic, and serialization errors fail fast.

### What delivery guarantee did you implement?

At-least-once. It is simpler and appropriate for this stage, but consumers need
idempotency because duplicates are possible.

### How did you test it without Kafka?

I used fake publishers and fake Kafka writers. Unit tests verify schemas,
topic/key selection, publish decisions, retry behavior, error classification,
and observability collector exposure.

### How do you prove it works with Kafka?

Run the integration validation runbook: enable the producer, send a webhook,
consume from the heartbeat and WAN status topics, and verify logs and metrics.

## Debug Flow

1. Check webhook response and `acs_webhook_errors_total`.
2. Search logs for `event=kafka_publish`.
3. Look at `result`, `topic`, `key`, `kind`, `attempts`, and `duration_ms`.
4. Check producer metrics by topic and error kind.
5. Verify topic existence with `kafka-topics.sh`.
6. Confirm Kafka service DNS and network policy.
7. Consume from the expected topic with key printing enabled.

## Tradeoffs

Feature flag:
Safe rollout, but production must ensure the flag is enabled when Kafka
publication is expected.

JSON:
Easy to inspect, but schema registry may be useful later.

At-least-once:
Good incremental reliability, but consumers must handle duplicates.

DB plus Kafka:
Preserves durable intake, but it is a dual-output path and needs clear
observability.

## Resume Bullet

Implemented a feature-flagged Kafka producer path for `acs-ingest`, publishing
normalized heartbeat and WAN status events with stable device keys, bounded
retry/error handling, Prometheus metrics, structured logs, broker-free unit
tests, and operational runbooks for live validation and incident response.

## Files To Mention

* `app/pkg/events/heartbeat.go`
* `app/pkg/events/wan_status.go`
* `app/pkg/events/publisher.go`
* `app/pkg/events/kafka_producer.go`
* `app/acs-ingest/main.go`
* `ADR/acs-ingest-kafka-producer-migration.md`
* `ops/runbooks/acs-ingest-kafka-producer-validation.md`
* `ops/runbooks/acs-ingest-kafka-producer-operations.md`
