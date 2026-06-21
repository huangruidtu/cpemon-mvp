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

The initial adapter focused on construction, serialization, topic/key
selection, write, and close lifecycle. `CCPU-82` extends it with explicit retry
and error classification.

## Producer Retry and Error Handling

`KafkaProducer` now makes publish failures explicit with `KafkaPublishError`.

Error fields:

| Field | Meaning |
| --- | --- |
| `Kind` | High-level class such as `invalid_event`, `serialization_error`, `timeout`, or `writer_error`. |
| `Topic` | Kafka topic selected by the normalized event. |
| `Key` | Kafka message key, currently stable device identity. |
| `Attempts` | Number of writer attempts made before returning the error. |
| `Err` | Wrapped root cause returned by validation, JSON marshaling, context, or the Kafka writer. |

Fail-fast behavior:

* Nil producer or nil event.
* Empty topic.
* Empty key.
* JSON serialization error.

These failures are not retried because another network attempt cannot repair an
invalid application event.

Retry behavior:

* Writer errors are retried up to `KafkaProducerMaxRetries`.
* The producer makes `1 + KafkaProducerMaxRetries` total writer attempts.
* Each attempt uses the configured per-publish timeout.
* Parent context cancellation stops the retry loop immediately.

Delivery semantics:

The producer is designed for at-least-once publishing. Retrying can create
duplicates if Kafka accepts a write but the client sees an ambiguous timeout or
network error. Consumers should therefore be idempotent and should use stable
keys plus event timestamps or future event IDs to de-duplicate where needed.

Incident drill:

1. Check the application log for `KafkaPublishError` fields: kind, topic, key,
   attempts, and wrapped error.
2. If `kind=timeout`, verify broker reachability and whether the configured
   timeout is too low for the environment.
3. If `kind=writer_error`, check Kafka broker health, bootstrap DNS, topic
   existence, ACLs, and broker-side request size limits.
4. If `kind=serialization_error`, inspect the event schema and mapper; do not
   retry blindly.
5. If duplicates are suspected after recovery, query by device key and event
   timestamp before replaying downstream effects.

## Producer Metrics and Structured Logging

`CCPU-83` adds producer telemetry for success, failure, latency, and debugging
context.

Metrics exposed by `acs-ingest`:

| Metric | Type | Labels | Meaning |
| --- | --- | --- | --- |
| `acs_ingest_kafka_producer_publishes_total` | Counter | `topic`, `result` | Completed publish calls grouped by topic and `success` or `error`. |
| `acs_ingest_kafka_producer_publish_errors_total` | Counter | `topic`, `kind` | Publish failures grouped by topic and error kind. |
| `acs_ingest_kafka_producer_publish_duration_seconds` | Histogram | `topic`, `result` | Publish latency grouped by topic and result. |

The producer exposes collectors through `KafkaProducerCollectors()`, and
`acs-ingest` registers them with the existing Prometheus metrics endpoint.

Structured log shape:

```text
event=kafka_publish result=success topic=cpemon.device.heartbeat.v1 key=CPE-001 attempts=1 duration_ms=3
event=kafka_publish result=error topic=cpemon.device.heartbeat.v1 key=CPE-001 kind=writer_error attempts=4 duration_ms=5001 error="..."
```

Logging boundary:

* Logs include topic, key, result, attempts, duration, error kind, and error
  message.
* Logs do not dump full event payloads because payloads may contain sensitive
  device or network details.
* Metrics avoid the message key as a label because device identity would create
  high-cardinality Prometheus series.

Debug flow:

1. Start from the webhook status and `acs_webhook_errors_total`.
2. Check `event=kafka_publish` logs for topic, key, attempts, duration, and
   error kind.
3. Compare publish success/error counters by topic.
4. Inspect publish duration histogram for timeout or broker latency patterns.
5. Validate Kafka topic existence and broker health.
6. Confirm consumers receive the expected topic/key pair.

## Unit Test Boundary

`CCPU-84` documents and tightens the unit-test boundary for the producer
refactor.

Unit tests cover:

* Heartbeat event mapping, topic, key, schema version, and JSON contract.
* WAN status event mapping, derived WAN status, optional fields, missing WAN
  data, invalid JSON, topic, key, and JSON contract.
* `EventPublisher` as an interface boundary using fake publishers.
* `KafkaProducer` construction, topic/key validation, JSON serialization,
  writer errors, retry behavior, timeout classification, close lifecycle, and
  observability collector exposure.
* `acs-ingest` publish wiring with fake publishers, including disabled
  publisher behavior, heartbeat + WAN publish, WAN skip, WAN build failure, and
  publish error propagation.

Unit tests intentionally do not prove:

* A real Kafka broker is reachable.
* Kafka topics exist in the target cluster.
* ACLs, DNS, listener config, and broker-side message-size limits are correct.
* A consumer can read the event after a real publish.

Those are integration concerns and stay in the dedicated integration validation
subtask.

Repository command:

```powershell
go test ./...
```

Interview-ready explanation:

> I kept the fast unit tests broker-free. They prove the contract mapping,
> interface boundary, retry/error behavior, and handler publish decisions. Live
> broker connectivity and produce/consume confirmation belong to integration
> validation because they depend on cluster state.

## Integration Validation Path

`CCPU-163` adds a repeatable live validation runbook:

```text
ops/runbooks/acs-ingest-kafka-producer-validation.md
```

The runbook validates:

* `acs-ingest` has Kafka producer configuration enabled.
* A sample ACS webhook returns `202 Accepted`.
* Heartbeat is consumed from `cpemon.device.heartbeat.v1`.
* WAN status is consumed from `cpemon.wan.status.v1`.
* Message key is stable device identity.
* Payload shape matches the normalized event contracts.
* Producer success logs and metrics are visible.

Repository validation command:

```powershell
make acs-ingest-kafka-producer-validation-check
```

The repository command validates the runbook and surrounding artifacts. It does
not claim live broker proof unless the runbook is executed against a real
cluster.

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
