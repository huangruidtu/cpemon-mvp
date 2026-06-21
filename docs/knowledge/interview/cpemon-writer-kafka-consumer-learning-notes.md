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

Application-side processing gap:
The difference between the last consumed offset and the last committed offset
inside `cpemon-writer`. This is useful, but it is not the same as broker lag.

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

The concrete implementation keeps `kafka-go` auto-commit disabled and calls
`CommitMessages` only after the writer handler returns success.

### What delivery guarantee does this design target?

At-least-once processing. It avoids message loss but requires idempotent writes
because duplicate processing is possible.

### What happens if committing the offset fails after MySQL succeeds?

The consumer returns a `commit_error` with topic, key, partition, and offset
context. Kafka may redeliver the message because the committed offset is not
guaranteed, so the database write path must tolerate duplicate events.

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

### Why add a common event processor?

It gives the consumer loop one processing entry point. The router dispatches by
topic, so heartbeat and WAN status keep separate validation/write logic while
retry, dead-letter, offset commit, metrics, and logs can wrap one function.

### What is a poison message?

A poison message is an event that will not succeed if retried unchanged. Common
examples are invalid JSON, a missing required field, a wrong schema version, an
unknown topic, or a key that does not match the device identity.

### Why are infinite retries dangerous?

Kafka preserves order within a partition. If one poison message is retried
forever, later valid messages in the same partition can be blocked. Bounded
retries plus dead-letter handling keep the system moving while preserving the
bad event for debugging.

### Which failures should retry?

Transient infrastructure failures should retry: MySQL unavailable, temporary
timeouts, or a short network interruption. Payload contract failures should not
retry because waiting will not make malformed JSON valid.

### When can the consumer commit a dead-lettered message?

Only after the dead-letter event has been published successfully. At that point
the original event is no longer lost; it has moved to an operational queue where
it can be inspected, replayed, or fixed manually.

### What if dead-letter publishing fails?

The handler returns an error, so the Kafka adapter does not commit the original
offset. That is conservative: it may cause a retry, but it avoids losing the
failed event completely.

### What metrics did you add for consumer lag?

I added low-cardinality Prometheus gauges for last consumed offset, last
committed offset, message age, and reader-reported lag when the Kafka client can
provide it. The labels are `group`, `topic`, and `partition`.

### Why not label metrics with device id or serial number?

Device ids are high-cardinality labels. Putting them into Prometheus metrics can
create too many time series and hurt the monitoring system. Device-specific
debugging belongs in logs, payloads, or dead-letter events.

### How do you check true Kafka consumer lag?

Use the broker view:

```powershell
kafka-consumer-groups.sh --bootstrap-server <broker> --describe --group cpemon-writer
```

The important columns are `CURRENT-OFFSET`, `LOG-END-OFFSET`, and `LAG`.

### Why are application metrics not always authoritative lag?

In consumer group mode, the Kafka client may not expose true broker lag from
the reader. The app metrics show local consume/commit progress and message age.
The broker-side consumer group description is still the source of truth for
lag.

### What processing metrics did you add?

I added counters for processing outcomes, retries, and dead-letter publish
outcomes, plus a histogram for processing duration. The labels are deliberately
low-cardinality: topic, result, and failure kind.

### What do the structured logs include?

The logs use stable key-value fields such as
`event=writer_kafka_process`, `result=retry`, topic, key, partition, offset,
attempt count, `duration_ms`, failure kind, and error text. That gives enough
context to debug one event without putting device ids or raw errors into metric
labels.

### Why split metrics and logs this way?

Metrics are for aggregate questions: error rate, retries, dead-letter volume,
and latency. Logs are for single-event investigation: which topic, key,
partition, offset, attempt, and error caused the issue.

### How did you unit test the consumer without Kafka?

I used fake consumers, fake readers, fake SQL executors, and fake publishers.
That lets tests verify the application contract, routing, decode failures,
idempotent writes, retry decisions, dead-letter behavior, and offset commit
decisions without starting a broker.

### What belongs in unit tests versus integration tests?

Unit tests cover deterministic code decisions: how one event is decoded, routed,
written, retried, dead-lettered, or committed. Integration tests should cover
the live Kafka-to-DB path: real broker connectivity, topic creation, consumer
group assignment, and end-to-end API-visible state changes.

### Why are broker-free unit tests valuable?

They run fast and fail close to the code that made the decision. If a test for
poison-message DLQ behavior fails, I know the issue is in processing logic, not
Kafka networking, topic metadata, or local cluster state.

### How do you prove Kafka-to-DB integration?

Run the live validation path: enable `KAFKA_CONSUMER_ENABLED=true`, produce a
keyed heartbeat event and a keyed WAN status event into Kafka, then verify that
`cpemon-writer` updates `cpe_status` and `cpe_status_history` in MySQL. Also
check the `cpemon-writer` consumer group offsets and writer Kafka metrics.

### What is the boundary if no live cluster is available?

The repository check can prove that the runbook, code wiring, config keys,
commands, and docs exist. It does not prove live broker-to-DB behavior. That
requires a running Kafka broker, `cpemon-writer`, MySQL, and real messages.

### Why keep unit proof and integration proof separate?

Unit tests explain whether the consumer logic is correct. Integration
validation explains whether the deployed system works: DNS, topics, consumer
group membership, Kafka records, database connectivity, schema, offset commits,
and metrics.

### Why use a bounded commit timeout?

Offset commits are part of the reliability path, but they should not hang
shutdown forever. A short `KAFKA_CONSUMER_COMMIT_TIMEOUT` gives an already
processed message a chance to be acknowledged while keeping shutdown bounded.

### Why not use the request cancellation context directly for commits?

If shutdown arrives just after the handler succeeds, using the already-canceled
context could skip the commit for a successfully written event. The adapter uses
`context.WithoutCancel` plus a timeout so commit has a small independent window
without becoming unbounded.

## Resume Bullet

Defined the writer-side Kafka consumer boundary with a broker-independent
`EventConsumer` interface and `ConsumedEvent` envelope, enabling testable
consumer logic with explicit topic, key, payload, partition, offset, context,
handler error, and close lifecycle behavior.

Implemented the first concrete Kafka consumer adapter with `kafka-go`,
consumer-group topic subscription, app-config construction, structured consume
errors, broker-free fake-reader tests, and an explicit offset-commit boundary
for the later reliability subtask.

Added explicit at-least-once offset commit behavior: auto-commit stays disabled,
successful handler execution is followed by `CommitMessages`, handler failures
are not committed, commit failures return contextual `commit_error` values, and
the docs explain why idempotent MySQL writes are required.

Added bounded retry and dead-letter handling for the writer consumer path:
transient processing errors retry with configured backoff, poison messages are
published to `cpemon.deadletter.v1`, retry exhaustion also dead-letters the
event, and original offsets are committed only after successful processing or
successful dead-letter publication.

Added consumer lag telemetry with low-cardinality group/topic/partition labels:
last consumed offset, last committed offset, message age, and reader-reported
lag when available, plus a runbook explaining how to confirm authoritative lag
with Kafka consumer group offsets.

Added writer processing observability: low-cardinality processing, retry,
dead-letter, and duration metrics plus structured logs that carry topic, key,
partition, offset, attempts, failure kind, `duration_ms`, and error context.

Consolidated broker-free consumer unit coverage across interface, adapter,
decode, routing, idempotent MySQL writes, offset commit, retry/dead-letter, and
shutdown/fallback edge cases.

Added Kafka-to-DB validation wiring and runbook: when
`KAFKA_CONSUMER_ENABLED=true`, `cpemon-writer` starts the Kafka consumer loop,
uses the dead-letter publisher, processes heartbeat and WAN status events, and
the runbook verifies MySQL state plus consumer group offsets.
