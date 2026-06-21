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

