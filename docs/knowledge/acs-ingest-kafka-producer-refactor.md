# acs-ingest Kafka Producer Refactor

## Purpose

Story 9 moves `acs-ingest` toward publishing normalized device events to Kafka.

The first contract is the heartbeat event for topic `cpemon.device.heartbeat.v1`.
The important design decision is that the event is a normalized CPEmon domain
event, not a raw ACS webhook payload.

## Heartbeat Event Contract

Topic:

```text
cpemon.device.heartbeat.v1
```

Message key:

```text
device_id
```

For the current CPEmon model, `device_id` is the ACS serial number. The event
also keeps `serial_number` explicitly so the payload remains easy to inspect.

Payload fields:

| Field | Meaning |
| --- | --- |
| `schema_version` | Contract version. Current value: `v1`. |
| `event_type` | Current value: `device.heartbeat`. |
| `source` | Source system, normally `acs`. |
| `device_id` | Stable Kafka message key and device identity. |
| `serial_number` | Original ACS serial number. |
| `event_ts` | Timestamp from the ACS event, normalized to UTC. |
| `received_at` | Time the ingest service created the normalized event. |
| `status` | Heartbeat status. Current value: `online`. |

Example:

```json
{
  "schema_version": "v1",
  "event_type": "device.heartbeat",
  "source": "acs",
  "device_id": "CPE-001",
  "serial_number": "CPE-001",
  "event_ts": "2026-06-21T10:30:00Z",
  "received_at": "2026-06-21T10:31:00Z",
  "status": "online"
}
```

## Mapping From Current Model

The current `acs-ingest` path builds `model.IngestEvent` with:

* `Source`
* `SN`
* `EventTS`
* raw JSON `Payload`

`NewDeviceHeartbeatEvent` maps that model to the Kafka contract:

* `SN` becomes `device_id` and `serial_number`
* `EventTS` becomes `event_ts`
* `Source` becomes `source`, defaulting to `acs` when absent
* `received_at` is supplied by the caller
* `status` is set to `online`

## Validation Boundary

This subtask defines and tests the heartbeat event schema only.
It does not yet publish to Kafka. Producer implementation, application wiring,
retry/error handling, and live Kafka validation are handled by later subtasks.

## Interview Notes

A strong explanation:

> I introduced the heartbeat schema before the producer because event contracts
> are the stable boundary between services. Kafka topics should carry normalized
> domain events, not raw webhook payloads. That keeps consumers decoupled from
> ACS-specific request shape and lets the team version the contract explicitly.

Key points to mention:

* Topic name follows `cpemon.<domain>.<event-family>.v<major>`.
* The message key is stable device identity, so events for the same device can
  be ordered within a partition.
* The schema records both event time and ingest time.
* The schema is unit-testable without Kafka.

## WAN Status Event Contract

Topic:

```text
cpemon.wan.status.v1
```

Message key:

```text
device_id
```

For the current CPEmon model, `device_id` is again the ACS serial number. This
keeps all events for a device keyed consistently across heartbeat and WAN
status topics.

Payload fields:

| Field | Meaning |
| --- | --- |
| `schema_version` | Contract version. Current value: `v1`. |
| `event_type` | Current value: `wan.status`. |
| `source` | Source system, normally `acs`. |
| `device_id` | Stable Kafka message key and device identity. |
| `serial_number` | Original ACS serial number. |
| `event_ts` | Timestamp from the ACS event, normalized to UTC. |
| `received_at` | Time the ingest service created the normalized event. |
| `wan_status` | Normalized WAN state, for example `up`. |
| `wan_ip` | Optional WAN IP address from the ingest payload. |
| `sw_version` | Optional software version metadata when present. |

Example:

```json
{
  "schema_version": "v1",
  "event_type": "wan.status",
  "source": "acs",
  "device_id": "CPE-001",
  "serial_number": "CPE-001",
  "event_ts": "2026-06-21T10:30:00Z",
  "received_at": "2026-06-21T10:31:00Z",
  "wan_status": "up",
  "wan_ip": "10.0.0.13",
  "sw_version": "v1.0-demo"
}
```

The mapper accepts `wan_status`, `wan_state`, or `status` from the raw payload.
If the payload has `wan_ip` but no explicit status, the event derives
`wan_status: up`. If neither status nor `wan_ip` is present, the mapper returns
an error so the caller does not publish a misleading WAN event.

## EventPublisher Boundary

`EventPublisher` is the application-side boundary that lets `acs-ingest`
publish normalized events without depending directly on a Kafka client.

The interface is intentionally small:

```go
type PublishableEvent interface {
    Topic() string
    Key() string
}

type EventPublisher interface {
    Publish(ctx context.Context, event PublishableEvent) error
}
```

Why this shape:

* `context.Context` carries request cancellation and timeout behavior.
* `Topic()` keeps topic selection with the event contract.
* `Key()` keeps the partition-key strategy with the event contract.
* `error` makes publish failure explicit to the caller.
* Tests can use a fake publisher without Kafka.

The concrete Kafka producer remains a later adapter. This subtask only defines
the dependency-inversion boundary used by future producer and handler wiring.

## Producer Configuration Boundary

`acs-ingest` reads producer configuration from environment variables that are
wired through the CPEmon Helm chart and the raw Kubernetes ConfigMap.

Application config keys:

| Environment variable | Default | Purpose |
| --- | --- | --- |
| `KAFKA_PRODUCER_ENABLED` | `false` | Feature boundary for app-side producer behavior. |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka.kafka.svc.cluster.local:9092` | Kafka bootstrap address from Story 8. |
| `KAFKA_TOPIC_DEVICE_HEARTBEAT` | `cpemon.device.heartbeat.v1` | Heartbeat topic contract. |
| `KAFKA_TOPIC_WAN_STATUS` | `cpemon.wan.status.v1` | WAN status topic contract. |
| `KAFKA_TOPIC_DEADLETTER` | `cpemon.deadletter.v1` | Dead-letter topic contract. |
| `KAFKA_PRODUCER_TIMEOUT` | `5s` | Per-publish timeout used by the producer adapter. |
| `KAFKA_PRODUCER_MAX_RETRIES` | `3` | Maximum producer retry attempts. |

The producer is disabled by default in application config because this story is
introducing the wiring before the concrete Kafka adapter and handler refactor
are complete. The bootstrap server and topic defaults still point at the Story
8 Kafka platform contract, so enabling the producer later does not require
changing application code.

## Kafka Producer Adapter

`KafkaProducer` is the concrete implementation of `EventPublisher`.

Implementation choices:

* Client library: `github.com/segmentio/kafka-go`.
* Payload encoding: JSON marshaling of the normalized event struct.
* Topic selection: `event.Topic()`.
* Message key: `event.Key()`.
* Balancer: hash balancer, so the same device key is routed consistently.
* Acknowledgement: `RequireOne`, enough for this Step 1 learning path.
* Lifecycle: explicit `Close()` so the underlying writer can flush/close.

The producer validates that every event has a non-empty topic and key before it
writes to Kafka. It returns errors with topic/key context so the caller and
logs can explain which publish failed.

Retry behavior is still handled by the later retry/error-handling subtask. This
adapter keeps the first producer implementation focused on construction,
serialization, topic/key selection, write, and close lifecycle.

## acs-ingest Publish Wiring

`acs-ingest` now wires the producer into the webhook flow behind
`KAFKA_PRODUCER_ENABLED`.

Runtime behavior:

* When `KAFKA_PRODUCER_ENABLED=false`, the publisher is nil and the existing
  enqueue-only behavior is preserved.
* When `KAFKA_PRODUCER_ENABLED=true`, startup creates a `KafkaProducer` from
  app config and closes it during service shutdown.
* The webhook handler still validates the request, parses the ACS payload, and
  writes the raw ingest event to `ingest_events` first.
* After the database enqueue succeeds, the handler publishes normalized Kafka
  events through `EventPublisher`.
* A heartbeat event is published for every valid ACS webhook.
* A WAN status event is published only when the raw payload contains WAN status
  data, or a WAN IP from which the mapper can derive `wan_status: up`.

The ordering is intentional: the database remains the durable local intake
record, and Kafka publishing happens only after the request has passed
validation and has been persisted.

Failure behavior:

* If publishing fails while the producer is enabled, the handler returns `500`
  and records `kafka_publish_error`.
* Missing WAN data is not treated as a publish failure because many heartbeat
  webhooks may not carry WAN details.
* Invalid WAN JSON or invalid heartbeat fields remain real build failures and
  are returned to the caller.

Interview-ready explanation:

> I kept Kafka behind a feature flag and published normalized events only after
> the ingest record was stored. That preserves the current rollout path while
> adding an event-driven boundary. Heartbeat is mandatory for every accepted
> webhook; WAN status is conditional because it represents a richer signal that
> may not be present in every ACS payload.
