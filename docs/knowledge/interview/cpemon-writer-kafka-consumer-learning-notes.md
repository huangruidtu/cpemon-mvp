# cpemon-writer Kafka Consumer Learning Notes

Use this as the interview review sheet for Story 10.

## 60-Second Story

After adding Kafka publishing to `acs-ingest`, I started the consumer side in
`cpemon-writer`. The goal is to consume normalized heartbeat and WAN status
events, update MySQL, and let `cpemon-api` read the latest device state.

I began with a small `EventConsumer` interface and a `ConsumedEvent` envelope.
That keeps writer business logic independent from the Kafka client. The
consumer adapter can translate Kafka records into application events, while
tests can use fake consumers to verify routing, decoding, database writes,
retry behavior, and offset decisions without starting a broker.

## Mental Model

```text
Kafka topic
  -> concrete Kafka consumer adapter
  -> ConsumedEvent
  -> writer event handler
  -> MySQL write
  -> offset commit after success
```

## Key Concepts

Consumer group:
Multiple `cpemon-writer` instances can share work. Kafka assigns partitions to
group members.

Partition:
An ordered shard of a topic. Events for the same device should use the same key
so they route consistently.

Offset:
The position of a message within a partition. Committing an offset means the
consumer group has acknowledged progress.

At-least-once processing:
The consumer should commit only after successful processing. If it crashes after
writing to MySQL but before committing, the message may be processed again.

Idempotent write:
The database update path must tolerate duplicate events because retries and
crash recovery can replay the same message.

Dead-letter handling:
Malformed or unprocessable messages should be isolated after bounded attempts so
one bad payload does not block the partition forever.

Lag:
The difference between the latest broker offset and the consumer group's
committed offset. Lag growth tells us the writer is falling behind.

Feature flag:
`KAFKA_CONSUMER_ENABLED` keeps the Kafka path off by default while the migration
is introduced. This lets the team ship config and wiring before changing the
runtime processing path.

Consumer group id:
`KAFKA_CONSUMER_GROUP_ID=cpemon-writer` gives all writer replicas a shared
offset identity. If the group id changes, Kafka treats it as a new consumer
group and starts from the configured offset behavior.

Partition ownership:
Within one consumer group, a topic partition is assigned to one active consumer
at a time. Scaling `cpemon-writer` can increase parallelism only up to the
number of partitions in the subscribed topics.

## Strong Q&A

### Why introduce `EventConsumer`?

To keep `cpemon-writer` business logic independent from Kafka client details.
The writer can be tested with a fake consumer, and the Kafka adapter can change
without rewriting the processing logic.

### Why include partition and offset in `ConsumedEvent`?

Consumer reliability depends on offset management. Partition and offset also
make debugging concrete: logs can identify the exact message that failed.

### Why should the handler return an error?

The adapter needs to know whether processing succeeded before committing an
offset. An error means the event may need retry or dead-letter handling.

### When should offsets be committed?

After the event is decoded, validated, and written to MySQL. Committing earlier
can lose messages if the process crashes before the database update.

### What delivery guarantee does this design target?

At-least-once processing. It avoids message loss but requires idempotent writes
because duplicate processing is possible.

### Why keep the consumer disabled by default?

Because this is an incremental migration. The existing DB queue path remains the
known-safe behavior while we add config, adapter, processing, retry, metrics,
and validation step by step.

### What happens if the consumer group id changes?

Kafka treats it as a different group with a different committed offset history.
That can be useful for a controlled replay, but it is dangerous as an accidental
config change because it may reprocess old messages or appear to skip expected
group progress.

### How can you test this without Kafka?

Use a fake `EventConsumer` that feeds `ConsumedEvent` values into the handler.
That tests routing, error propagation, and future write behavior without broker
setup.

### What does the Kafka adapter do?

It owns Kafka mechanics: bootstrap servers, consumer group id, topic
subscription, `FetchMessage`, and close lifecycle. It converts each
`kafka.Message` into `ConsumedEvent` so writer processing stays independent from
the Kafka client.

### Why subscribe to heartbeat as its own topic?

Heartbeat is the minimum liveness signal. Keeping
`cpemon.device.heartbeat.v1` as its own topic makes the contract easy to route,
scale, test, and explain independently from richer event families such as WAN
status.

### Why is WAN status a separate topic?

WAN status is a richer connectivity signal. It may have different payload
requirements, validation failures, update rules, and operational meaning than
heartbeat. Keeping it on `cpemon.wan.status.v1` lets the writer route and debug
it independently.

### Why use `FetchMessage` instead of hiding commits?

`FetchMessage` lets the application choose when to commit offsets. That matters
because `cpemon-writer` should acknowledge progress only after the database
write succeeds.

### How does heartbeat update MySQL?

The writer decodes `DeviceHeartbeatEvent`, validates the schema and device
identity, then updates `cpe_status.last_seen` and appends or updates
`cpe_status_history`. The update is idempotent so a replay of the same heartbeat
does not break processing.

### Why not let old heartbeat events overwrite newer status?

Kafka can replay messages after retries, crashes, or group changes. The current
status table should represent the latest known state, so the heartbeat upsert
keeps the newer `last_seen` when an older replay arrives.

### How does WAN status update MySQL?

The writer decodes `WANStatusEvent`, validates the schema, device identity,
message key, `wan_status`, and timestamp, then updates `cpe_status` with
`last_seen`, `wan_ip`, and `sw_version`. It also writes `cpe_status_history` so
the event remains visible in historical debugging.

### Why validate `wan_status` if the table does not store it?

The current schema has `wan_ip` and `sw_version`, but no separate `wan_status`
column. Validating `wan_status` still matters because it distinguishes a real
WAN event from a malformed payload. The storage model can be expanded later
without weakening the event contract today.

## Resume Bullet

Defined the writer-side Kafka consumer boundary with a broker-independent
`EventConsumer` interface and `ConsumedEvent` envelope, enabling testable
consumer logic with explicit topic, key, payload, partition, offset, context,
handler error, and close lifecycle behavior.

Implemented the first concrete Kafka consumer adapter with `kafka-go`,
consumer-group topic subscription, app-config construction, structured consume
errors, broker-free fake-reader tests, and an explicit offset-commit boundary
for the later reliability subtask.
