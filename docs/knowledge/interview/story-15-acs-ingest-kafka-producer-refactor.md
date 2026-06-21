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

