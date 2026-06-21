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

## Kafka Consumer Adapter

`CCPU-87` adds the concrete Kafka adapter:

```go
type KafkaConsumer struct {
    reader kafkaMessageReader
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
* Returns structured `KafkaConsumeError` values for fetch and handler failures.

Offset commit behavior is intentionally not finalized in `CCPU-87`.
`FetchMessage` makes commit timing explicit, and `CCPU-169` owns the rule:
commit offsets only after successful processing and MySQL write.

Broker-free tests cover:

* invalid construction
* construction from app config
* fake reader injection
* topic/key/value/time/partition/offset mapping
* fetch error classification
* handler error context
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
