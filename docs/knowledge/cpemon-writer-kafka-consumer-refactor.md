# cpemon-writer Kafka Consumer Refactor

## Purpose

Story 10 moves `cpemon-writer` toward consuming normalized CPEmon events from
Kafka and updating MySQL read models.

The producer side already exists in Story 9:

```text
acs-ingest -> Kafka topics -> cpemon-writer -> MySQL -> cpemon-api
```

`CCPU-86` starts the consumer side by defining the application boundary before
adding a concrete Kafka client.

## EventConsumer Boundary

`EventConsumer` is the writer-side equivalent of the producer-side
`EventPublisher`.

```go
type ConsumedEvent struct {
    Topic     string
    Key       string
    Value     []byte
    Time      time.Time
    Partition int
    Offset    int64
}

type EventHandler func(ctx context.Context, event ConsumedEvent) error

type EventConsumer interface {
    Consume(ctx context.Context, handler EventHandler) error
    Close() error
}
```

The interface is intentionally small. `cpemon-writer` business logic should know
that an event arrived, what topic it came from, what key was used, what payload
must be decoded, and which partition/offset identify the message for debugging
and later offset handling.

It should not depend directly on `segmentio/kafka-go`, Kafka readers, broker
connections, or consumer group implementation details.

## Why This Matters

The consumer has stricter correctness concerns than the producer:

* It must avoid committing offsets before MySQL writes succeed.
* It must handle duplicate delivery because Kafka processing is at-least-once.
* It must classify malformed payloads separately from transient database errors.
* It must expose enough metadata to debug lag, poison messages, and replays.

By defining `ConsumedEvent` first, the application can test those decisions with
fake consumers before introducing a real Kafka adapter.

## Metadata Included

| Field | Why it exists |
| --- | --- |
| `Topic` | Routes heartbeat and WAN status events to the correct decoder/handler. |
| `Key` | Carries stable device identity; useful for logs and partition reasoning. |
| `Value` | Raw payload bytes to decode into the shared event contract. |
| `Time` | Kafka message time for debugging event freshness and replay behavior. |
| `Partition` | Identifies where the message came from during lag/incident analysis. |
| `Offset` | Identifies the exact consumed message and supports commit decisions later. |

## Testing Boundary

`CCPU-86` adds broker-free tests with a fake consumer. Those tests prove:

* writer code can depend on `EventConsumer` without Kafka
* handlers receive topic, key, payload, partition, and offset metadata
* handler errors are propagated back to the consumer boundary
* context cancellation stops consumption
* the consumer lifecycle has an explicit `Close()` method

Live Kafka reads belong to the later Kafka adapter and integration validation
subtasks.

## Consumer Configuration Boundary

`CCPU-166` adds the configuration surface for the future writer consumer.

The consumer is disabled by default so the existing DB polling/write path stays
understandable during migration.

| Environment variable | Default | Purpose |
| --- | --- | --- |
| `KAFKA_CONSUMER_ENABLED` | `false` | Feature flag for the writer Kafka consumer path. |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka.kafka.svc.cluster.local:9092` | Kafka bootstrap address shared with producer config. |
| `KAFKA_TOPIC_DEVICE_HEARTBEAT` | `cpemon.device.heartbeat.v1` | Heartbeat input topic. |
| `KAFKA_TOPIC_WAN_STATUS` | `cpemon.wan.status.v1` | WAN status input topic. |
| `KAFKA_TOPIC_DEADLETTER` | `cpemon.deadletter.v1` | Dead-letter topic for unprocessable events. |
| `KAFKA_CONSUMER_GROUP_ID` | `cpemon-writer` | Stable group id for writer replicas. |
| `KAFKA_CONSUMER_READ_TIMEOUT` | `5s` | Timeout for polling Kafka reads. |
| `KAFKA_CONSUMER_COMMIT_TIMEOUT` | `5s` | Timeout for committing offsets after success. |
| `KAFKA_CONSUMER_MAX_RETRIES` | `3` | Bounded retry attempts before dead-letter behavior. |
| `KAFKA_CONSUMER_RETRY_BACKOFF` | `1s` | Backoff between processing retry attempts. |

The Helm chart renders these settings through `appConfig` and wires them only
into `cpemon-writer`. Raw Kubernetes YAML keeps the same ConfigMap keys for
local or non-Helm validation.

Enablement example:

```yaml
appConfig:
  kafkaConsumerEnabled: true
  kafkaConsumerGroupId: cpemon-writer
```

Interview framing:

> I added the consumer config before the Kafka adapter so rollout behavior is
> explicit. The writer can remain on the DB polling path while the chart,
> ConfigMap, and application config already agree on the consumer contract.

## Consumer Group Configuration

`CCPU-91` makes the consumer group id an explicit contract.

Default:

```text
cpemon-writer
```

Why it matters:

* Kafka stores committed offsets by consumer group id.
* All `cpemon-writer` replicas in the same group share topic partitions.
* A partition is owned by one group member at a time.
* Changing the group id creates a new offset history.

The default group id is defined in code as `DefaultKafkaConsumerGroupID`, wired
through environment variable `KAFKA_CONSUMER_GROUP_ID`, and rendered by Helm as
`appConfig.kafkaConsumerGroupId`.

Operational reference:

```text
ops/runbooks/cpemon-writer-kafka-consumer-group.md
```

## Heartbeat Topic Subscription

`CCPU-88` makes the heartbeat subscription path explicit through
`KafkaConsumerTopicsFromConfig`.

The required heartbeat topic is:

```text
cpemon.device.heartbeat.v1
```

The topic remains configurable through:

```text
KAFKA_TOPIC_DEVICE_HEARTBEAT
```

Why it matters:

* heartbeat events are the minimum signal for device liveness
* the message key is stable device identity
* heartbeat processing can be routed separately from WAN status processing
* tests can prove the writer subscribes to the topic before live Kafka exists

Repository check:

```powershell
make cpemon-writer-heartbeat-subscription-check
```

## WAN Status Topic Subscription

`CCPU-89` adds the matching subscription proof for WAN status events.

The required WAN status topic is:

```text
cpemon.wan.status.v1
```

The topic remains configurable through:

```text
KAFKA_TOPIC_WAN_STATUS
```

Why it matters:

* WAN status is richer connectivity state, not just device liveness
* heartbeat and WAN status can evolve at different rates
* WAN-specific decoding and validation can fail without breaking heartbeat
  routing
* the writer can later map WAN status into a dedicated write model

Repository check:

```powershell
make cpemon-writer-wan-status-subscription-check
```

## Heartbeat Write Model

`CCPU-167` maps consumed heartbeat events into the existing MySQL read model.

Processing steps:

1. Verify the consumed topic is `cpemon.device.heartbeat.v1`.
2. Decode JSON into the shared `DeviceHeartbeatEvent` contract.
3. Validate schema version, event type, device identity, message key, status,
   and event timestamp.
4. Upsert `cpe_status.last_seen`.
5. Insert or update `cpe_status_history` for `(sn, event_ts)`.

The current status update is idempotent:

```sql
ON DUPLICATE KEY UPDATE
  last_seen = CASE
    WHEN last_seen IS NULL OR VALUES(last_seen) >= last_seen THEN VALUES(last_seen)
    ELSE last_seen
  END
```

This protects the read model from an older replay overwriting a newer
heartbeat. The history write also uses `ON DUPLICATE KEY UPDATE` so duplicate
delivery of the same `(sn, event_ts)` does not fail the consumer path.

Repository check:

```powershell
make cpemon-writer-heartbeat-write-model-check
```

Interview framing:

> Kafka consumers should assume at-least-once delivery. I made the heartbeat
> write path idempotent by updating current state only when the event is not
> older than the stored value and by making the history insert safe for duplicate
> `(sn, event_ts)` replays.

## WAN Status Write Model

`CCPU-168` maps consumed WAN status events into the existing MySQL read model.

Processing steps:

1. Verify the consumed topic is `cpemon.wan.status.v1`.
2. Decode JSON into the shared `WANStatusEvent` contract.
3. Validate schema version, event type, device identity, message key,
   `wan_status`, and event timestamp.
4. Upsert `cpe_status.last_seen`, `wan_ip`, and `sw_version`.
5. Insert or update `cpe_status_history` for `(sn, event_ts)`.

Current schema boundary:

The existing `cpe_status` table does not have a dedicated `wan_status` column.
For this subtask, `wan_status` is validated as the event signal, while the
persisted read model updates the fields that already exist:

* `last_seen`
* `wan_ip`
* `sw_version`

The write path is idempotent. Older replays do not overwrite newer current
status, and empty optional fields do not erase existing `wan_ip` or
`sw_version` values.

Repository check:

```powershell
make cpemon-writer-wan-status-write-model-check
```

Interview framing:

> I did not expand the database schema just to store `wan_status` because the
> current read model already exposes WAN IP and software version. I still
> validate `wan_status` because it proves the event is a real WAN status event,
> and I made the update replay-safe for at-least-once delivery.

## Event Processor Routing

`CCPU-90` adds the common `processConsumedEvent` entry point.

Routing rules:

| Topic | Processor |
| --- | --- |
| `cpemon.device.heartbeat.v1` | `processHeartbeatConsumedEvent` |
| `cpemon.wan.status.v1` | `processWANStatusConsumedEvent` |

Unsupported topics return an explicit error. This is deliberate: unknown event
families should not be silently acknowledged or written as untyped data.

This gives later reliability subtasks one place to wrap retry, dead-letter,
offset commit, metrics, and structured logging behavior.

Repository check:

```powershell
make cpemon-writer-event-processor-check
```

## Offset Commit Strategy

`CCPU-169` makes Kafka acknowledgement behavior explicit.

Rule:

> Fetch the message, process it through the writer handler, and commit the
> Kafka offset only after the handler returns success.

Why this order matters:

* Committing before validation can skip malformed messages without an audit path.
* Committing before the MySQL write can lose a status update if the process
  crashes between the commit and the database update.
* Returning a handler error without committing allows retry/dead-letter logic to
  decide what should happen next.
* A crash after MySQL success but before commit can replay the same message, so
  the MySQL write path must remain idempotent.

Implementation details:

* `kafka.ReaderConfig.CommitInterval` remains `0`, which means auto-commit is
  disabled.
* The adapter calls `CommitMessages` only after `EventHandler` returns nil.
* Commit failures are returned as `KafkaConsumeError` with kind
  `commit_error`, including topic, key, partition, and offset context.
* `KAFKA_CONSUMER_COMMIT_TIMEOUT` bounds commit latency.
* The commit context uses `context.WithoutCancel` plus a timeout so a shutdown
  signal does not cancel an already-successful in-flight acknowledgement before
  the short commit window expires.

Failure behavior:

| Failure Point | Commit Offset? | Why |
| --- | --- | --- |
| Fetch fails | No message fetched | There is no message to acknowledge. |
| Handler validation fails | No | The message needs retry/dead-letter classification. |
| MySQL write fails | No | Retrying is safer than losing durable state. |
| Commit fails after success | Unknown broker state | Return `commit_error`; replay must be safe. |
| Crash after DB write before commit | No confirmed commit | Kafka may redeliver; idempotent writes absorb duplicates. |

Repository check:

```powershell
make cpemon-writer-offset-commit-check
```

Interview framing:

> I used at-least-once processing deliberately. The writer commits the Kafka
> offset only after validation and MySQL writes succeed. That avoids message
> loss, but it means duplicates are possible after crashes or commit failures,
> so the database writes are idempotent.

## Retry And Dead-Letter Handling

`CCPU-92` adds the writer reliability wrapper around `processConsumedEvent`.

Processing shape:

```text
ConsumedEvent
  -> processConsumedEventWithReliability
  -> processConsumedEvent
  -> per-topic validation/write processor
  -> retry or dead-letter decision
  -> return nil only when it is safe for the Kafka adapter to commit
```

Failure classes:

| Class | Examples | Behavior |
| --- | --- | --- |
| `poison_message` | Invalid JSON, missing required fields, key/device mismatch, unsupported topic | Publish to `cpemon.deadletter.v1` without repeated retries. |
| `retriable_error` | MySQL unavailable, write timeout, transient infrastructure failure | Retry with bounded backoff, then publish to dead-letter after the limit. |

Why this boundary matters:

* Infinite retries can block a partition behind one bad message.
* Immediate commits can lose messages before the failure is inspected.
* Dead-letter publish success is the point where the original message can be
  acknowledged.
* Dead-letter publish failure returns an error so the original Kafka offset is
  not committed prematurely.

Dead-letter payload:

The `deadLetterEvent` contains:

* `schema_version` and `event_type`
* source topic and source key
* partition and offset
* failure kind and reason
* attempt count
* failed timestamp
* original payload as a debugging string

Repository check:

```powershell
make cpemon-writer-retry-deadletter-check
```

Interview framing:

> I separated transient failures from poison messages. Transient failures get a
> bounded retry policy. Poison messages go to a dead-letter topic because they
> will not become valid by waiting. The original offset is committed only after
> processing succeeds or after the dead-letter event is published successfully.

## Consumer Lag Metrics

`CCPU-93` adds low-cardinality Kafka consumer telemetry to `cpemon-writer`.

Registered collectors:

| Metric | Labels | Meaning |
| --- | --- | --- |
| `cpemon_writer_kafka_consumer_last_consumed_offset` | `group`, `topic`, `partition` | Last Kafka offset fetched by the writer consumer. |
| `cpemon_writer_kafka_consumer_last_committed_offset` | `group`, `topic`, `partition` | Last Kafka offset committed after successful processing. |
| `cpemon_writer_kafka_consumer_message_age_seconds` | `group`, `topic`, `partition` | Age of the last consumed message. |
| `cpemon_writer_kafka_consumer_reader_lag_messages` | `group`, `topic`, `partition` | Reader-reported lag when available. |

Label decision:

The metrics intentionally avoid high-cardinality labels such as device id,
serial number, message key, payload content, or raw error text. Those values
belong in structured logs or dead-letter payloads, not Prometheus label sets.

Lag boundary:

True Kafka lag is:

```text
LOG-END-OFFSET - CURRENT-OFFSET
```

In consumer group mode, `kafka-go` may not always provide true reader lag.
The application metrics expose local progress and message age. The authoritative
broker lag check is still:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-consumer-groups.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --describe `
  --group cpemon-writer
```

Runbook:

```text
ops/runbooks/cpemon-writer-kafka-consumer-lag.md
```

Repository check:

```powershell
make cpemon-writer-consumer-lag-check
```

Interview framing:

> I exposed writer-side consume and commit progress with group/topic/partition
> labels, but I did not pretend application metrics are always authoritative
> broker lag. True lag is the broker log-end offset minus the committed group
> offset, so the runbook pairs Prometheus metrics with
> `kafka-consumer-groups.sh --describe`.

## Writer Processing Metrics And Structured Logging

`CCPU-170` adds processing-level observability around retry and dead-letter
decisions.

Metrics:

| Metric | Labels | Meaning |
| --- | --- | --- |
| `cpemon_writer_kafka_processing_events_total` | `topic`, `result`, `kind` | Processing outcomes such as success, retry, dead-letter, or error. |
| `cpemon_writer_kafka_processing_retries_total` | `topic`, `kind` | Retry attempts grouped by failure kind. |
| `cpemon_writer_kafka_deadletters_total` | `topic`, `result`, `kind` | Dead-letter publish success/error outcomes. |
| `cpemon_writer_kafka_processing_duration_seconds` | `topic`, `result`, `kind` | End-to-end processing duration for one consumed event. |

Label boundary:

The processing metrics keep only low-cardinality labels: topic, result, and
failure kind. Device id, serial number, Kafka key, raw error text, and payload
content stay out of metric labels.

Structured log events:

```text
event=writer_kafka_process result=success topic=<topic> key=<key> partition=<n> offset=<n> attempts=<n> duration_ms=<n>
event=writer_kafka_process result=retry topic=<topic> key=<key> partition=<n> offset=<n> attempt=<n> kind=<kind> backoff_ms=<n> duration_ms=<n> error=<error>
event=writer_kafka_process result=error topic=<topic> key=<key> partition=<n> offset=<n> attempts=<n> kind=<kind> duration_ms=<n> error=<error>
event=writer_kafka_deadletter result=success source_topic=<topic> key=<key> partition=<n> offset=<n> attempts=<n> kind=<kind> duration_ms=<n> reason=<reason>
event=writer_kafka_deadletter result=error source_topic=<topic> key=<key> partition=<n> offset=<n> attempts=<n> kind=<kind> duration_ms=<n> error=<error>
```

The logs include Kafka key, partition, and offset because those identify one
event during incident response. They do not include secrets or database DSNs.

Repository check:

```powershell
make cpemon-writer-processing-observability-check
```

Interview framing:

> I kept metrics low-cardinality for dashboards and alerts, then used
> structured logs for single-event debugging. Metrics answer "what is failing
> and how often"; logs answer "which exact topic/key/partition/offset failed
> and why."

## Kafka Consumer Adapter

`CCPU-87` adds the concrete Kafka adapter:

```go
type KafkaConsumer struct {
    reader        kafkaMessageReader
    commitTimeout time.Duration
}
```

Construction:

* `NewKafkaConsumerFromConfig` reads the shared app config.
* `NewKafkaConsumer` validates bootstrap servers, group id, and topics.
* `NewKafkaConsumerWithReader` lets unit tests inject a fake reader.

Runtime behavior:

* Uses `github.com/segmentio/kafka-go`.
* Creates a consumer-group reader with `GroupTopics`.
* Reads messages with `FetchMessage`.
* Converts each `kafka.Message` to `ConsumedEvent`.
* Passes the envelope to the `EventHandler`.
* Commits the Kafka message only after the handler succeeds.
* Returns structured `KafkaConsumeError` values for fetch, handler, and commit
  failures.

Broker-free tests cover:

* invalid construction
* construction from app config
* fake reader injection
* topic/key/value/time/partition/offset mapping
* fetch error classification
* handler error context
* commit-after-success behavior
* no-commit-on-handler-error behavior
* commit error context
* close lifecycle

Interview framing:

> The Kafka adapter translates broker mechanics into the application envelope.
> That means the rest of `cpemon-writer` can talk in CPEmon concepts while the
> adapter owns broker connection, consumer group, topic subscription, and record
> metadata.

## Interview Notes

A strong explanation:

> I introduced `EventConsumer` before implementing Kafka consumption because
> the writer's business logic should depend on an application contract, not a
> Kafka client. The adapter can translate Kafka records into `ConsumedEvent`,
> while the writer can be tested with fake consumers and can make offset,
> retry, and database decisions in a clear layer.

Key points to mention:

* `EventPublisher` protects `acs-ingest`; `EventConsumer` protects
  `cpemon-writer`.
* The consumer envelope includes partition and offset because consumer
  reliability depends on commit timing.
* The handler returns an error so the adapter can decide whether to retry,
  dead-letter, or avoid committing the offset.
* Unit tests stay fast because they do not require a broker.
