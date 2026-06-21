# Story 15: acs-ingest Kafka Producer Refactor

## CCPU-79: Heartbeat Event Schema

`CCPU-79` defines the normalized heartbeat event contract for
`cpemon.device.heartbeat.v1`.

The schema is deliberately introduced before the producer implementation. That
keeps the message contract reviewable and testable before Kafka client behavior,
retry policy, and application wiring are added.

## Interview Q&A

### Why define the event schema before implementing the Kafka producer?

Because the event schema is the service contract. The producer is an adapter
that transports the contract. By defining the schema first, I can test mapping,
field names, topic naming, message key strategy, and versioning without needing
a live Kafka broker.

### Why not publish the raw ACS webhook payload directly?

Raw ACS payloads couple downstream consumers to the current webhook shape.
Normalized CPEmon events give consumers a stable domain contract with explicit
fields such as `device_id`, `event_ts`, `received_at`, and `status`.

### What is the message key?

The heartbeat event uses stable device identity as the message key. In the
current model this is the ACS serial number, exposed as `device_id`.

### Why include both `event_ts` and `received_at`?

`event_ts` is when the device event happened. `received_at` is when the ingest
service normalized the event. Keeping both lets us reason about delay, replay,
and incident timelines.

## CCPU-80: WAN Status Event Schema

`CCPU-80` defines the normalized WAN status event contract for
`cpemon.wan.status.v1`.

### Why make WAN status a separate event from heartbeat?

Heartbeat answers whether a device was seen. WAN status answers what the
connectivity state looked like when it was seen. Keeping them as separate event
families lets consumers subscribe to the signal they need and lets each schema
evolve independently.

### Why use the same message key as heartbeat?

Both events use stable device identity as the key. That makes partitioning and
debugging consistent: when investigating one device, the key is the same across
`device.heartbeat` and `wan.status`.

### What happens if the raw payload has no WAN data?

The mapper returns an error instead of publishing a weak event. A WAN status
event should contain either an explicit status field or a WAN IP from which the
current implementation can derive `wan_status: up`.

## CCPU-77: EventPublisher Interface

`CCPU-77` introduces the application boundary used by `acs-ingest` before the
Kafka client is implemented.

### Why introduce `EventPublisher` before adding Kafka?

Because ingestion logic should depend on a small application contract, not on a
concrete Kafka client. That keeps parsing, validation, event mapping, and
transport separate.

### What does the interface look like?

The boundary is:

```go
type EventPublisher interface {
    Publish(ctx context.Context, event PublishableEvent) error
}
```

The event supplies `Topic()` and `Key()`, so topic ownership and message-key
strategy stay with the event contract.

### How does this help testing?

Unit tests can use a fake publisher that records events in memory. That proves
the ingest flow asks to publish the right topic/key/event without needing a live
Kafka broker.

### What does the interface not solve yet?

It does not choose a Kafka client, configure retries, serialize payloads, or
flush producer buffers. Those are concrete adapter responsibilities in later
subtasks.

## CCPU-162: Producer Configuration and Helm Wiring

`CCPU-162` adds the app-side configuration contract for the future Kafka
producer.

### Why add config before implementing the producer?

Configuration is part of the application contract. By defining bootstrap
servers, topic names, timeout, retry count, and enablement before the adapter,
the producer implementation can be small and the deployment wiring can be
reviewed separately.

### Why keep `KAFKA_PRODUCER_ENABLED` false by default?

The project is still adding the producer adapter and handler refactor in later
subtasks. Keeping the producer disabled by default prevents accidental behavior
changes while still making the future configuration visible in Helm and raw
Kubernetes manifests.

### Which layer owns which Kafka setting?

Story 8 owns the platform-level Kafka service and topic names. Story 9 owns how
`acs-ingest` reads those settings and uses them to build a producer.

### What should you say in an interview?

I separated platform config from app config. Kafka can move from a Helm-based
cluster to Strimzi or MSK later, but `acs-ingest` only needs stable bootstrap
and topic settings from environment variables.

## CCPU-78: Kafka Producer Implementation

`CCPU-78` adds the concrete Kafka producer adapter behind the `EventPublisher`
interface.

### Which Go Kafka client did you choose?

I used `segmentio/kafka-go` because it is a pure Go client and fits this small
service without CGO or native librdkafka dependencies.

### What does the producer do?

It takes a `PublishableEvent`, validates `Topic()` and `Key()`, marshals the
event to JSON, and writes a Kafka message with that topic, key, value, and
timestamp.

### Why use a hash balancer?

The message key is stable device identity. A hash balancer keeps messages for
the same device key routed consistently, which supports per-device ordering
within a partition.

### Why does the producer have `Close()`?

Kafka writers own network resources and buffers. An explicit close lifecycle
makes shutdown behavior visible and prevents silent message loss during service
shutdown.

### What remains for later subtasks?

Retries, richer error classification, metrics, structured logging, application
handler wiring, and live produce/consume validation are handled by later
subtasks.

## CCPU-81: acs-ingest Kafka Publish Wiring

`CCPU-81` connects the `acs-ingest` webhook path to the `EventPublisher`
boundary.

### Where does publishing happen in the request flow?

The handler validates the request, parses the ACS payload, builds
`model.IngestEvent`, and writes it to `ingest_events` first. After that enqueue
succeeds, it publishes normalized Kafka events.

### Why publish after the database write?

The database is the durable local intake record. Publishing after the DB write
means an accepted webhook has already been captured before the service tries to
notify downstream Kafka consumers.

### What events are published?

Every valid ACS webhook publishes a `device.heartbeat` event. If the raw payload
contains WAN status data, the same flow also publishes a `wan.status` event.

### What happens if the payload has no WAN data?

The service skips the WAN event and still accepts the heartbeat. Missing WAN
data is not a failure because heartbeat and WAN status are separate event
families with different information requirements.

### Why keep the producer behind `KAFKA_PRODUCER_ENABLED`?

The feature flag lets the application deploy safely before Kafka publishing is
turned on in an environment. It also keeps local development and existing tests
from requiring a live Kafka broker.

### What should you say in an interview?

I separated durable intake from event publication. The webhook handler persists
the raw event first, then emits normalized Kafka contracts through an interface.
The feature flag gives a safe rollout path, and the unit tests verify the
publish decisions without needing Kafka.
