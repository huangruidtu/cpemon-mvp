# Story 16: cpemon-writer Kafka Consumer Refactor

Use this page as the long-form interview Q&A for the writer-side Kafka
consumer migration. Use `cpemon-writer-kafka-consumer-learning-notes.md` as the
quick review sheet.

## Story Summary

The CPEmon MVP originally used MySQL queue tables as the durable buffer between
ACS ingest and the writer. In the cloud-platform upgrade, Kafka becomes the
event buffer. Story 16 implements the consumer side: `cpemon-writer` consumes
normalized Kafka events, writes idempotent MySQL read models, exposes
observability, and keeps rollout behind a feature flag.

The target path is:

```text
acs-ingest
  -> Kafka topic
  -> cpemon-writer consumer group
  -> MySQL cpe_status and cpe_status_history
  -> cpemon-api read path
```

## Interview Narrative

I approached the consumer migration in layers. First I introduced a small
`EventConsumer` interface and a `ConsumedEvent` envelope so writer business
logic did not depend directly on `kafka-go`. Then I added config and a concrete
Kafka adapter with an explicit consumer group. After that, I mapped heartbeat
and WAN status events into idempotent MySQL writes, added a common router, and
made offset commits happen only after successful processing. Finally I added
bounded retries, dead-letter behavior, lag metrics, processing metrics,
structured logs, unit tests, integration runbooks, API validation, and an ADR
for rollout and rollback.

That sequence matters because the hardest part of a consumer migration is not
just reading from Kafka. The hard part is deciding what it means to safely
acknowledge a message after a database side effect.

## Q1: What problem did this story solve?

It moved `cpemon-writer` from an MVP-style polling/queue boundary toward a
Kafka event-consumer boundary. That gives the platform better producer/consumer
decoupling, replay potential, partition-based scaling, consumer group offsets,
lag visibility, and a more standard retry/dead-letter model.

## Q2: Why start with an `EventConsumer` interface?

The interface separates application behavior from the Kafka client. The writer
cares about topic, key, payload, message time, partition, offset, and handler
success or failure. It should not care which Kafka library is used or how the
reader is constructed. That also lets unit tests use fake consumers and fake
readers without starting a broker.

## Q3: Why does `ConsumedEvent` include partition and offset?

Partition and offset are the exact coordinates of a Kafka record. They make
logs, dead-letter events, retry debugging, and offset-commit behavior
concrete. Without them, an incident report would say "a message failed"; with
them, the team can find the exact message and consumer group position.

## Q4: Why use a consumer group id?

Kafka stores committed progress by consumer group. The default group id
`cpemon-writer` lets all writer replicas share partitions and commit progress
under one identity. It also gives operators a stable thing to inspect with
`kafka-consumer-groups.sh --describe --group cpemon-writer`.

## Q5: What happens if the consumer group id changes?

Kafka treats it as a new consumer group with a different offset history. That
can be useful for a controlled replay, but it is risky as an accidental config
change because the service may reprocess old events or appear to have no lag
history.

## Q6: Why keep the consumer disabled by default?

The migration is incremental. `KAFKA_CONSUMER_ENABLED=false` keeps the known
baseline available while config, Helm values, adapter code, processing logic,
observability, and runbooks are added. Rollout becomes a deployment decision
instead of a code rewrite.

## Q7: Why subscribe to heartbeat and WAN status as separate topics?

They are different event families. Heartbeat is the minimum liveness signal;
WAN status is richer connectivity state. Separate topics keep validation,
routing, monitoring, and future schema evolution simpler.

## Q8: Why key events by device identity?

The key helps keep events for the same device routed consistently to the same
partition, assuming a stable partition count. That preserves per-device order
within a partition and makes partition/offset debugging easier.

## Q9: What delivery guarantee does this design target?

At-least-once. The consumer commits offsets only after the handler succeeds.
That avoids losing messages before MySQL is updated, but duplicates can happen
after crashes or commit failures. The database writes must therefore be
idempotent.

## Q10: Why not commit before writing to MySQL?

Committing first acknowledges the Kafka message before the durable side effect.
If the process crashes after the commit and before the database write, Kafka
will not redeliver the message and the read model can miss an update.

## Q11: What if MySQL succeeds but the offset commit fails?

Kafka may redeliver the same event because committed progress is uncertain.
That is acceptable only because the heartbeat and WAN write models are
idempotent. The consumer returns a contextual `commit_error` so the failure is
visible with topic, key, partition, and offset.

## Q12: How did you make heartbeat writes idempotent?

The current-status upsert only advances `last_seen` when the incoming event is
newer than or equal to the stored value. The history write is safe for duplicate
`(sn, event_ts)` records. A replay of the same heartbeat therefore does not
break processing or move current state backward.

## Q13: How did you make WAN status writes idempotent?

The writer validates the WAN event contract, then updates `last_seen`, `wan_ip`,
and `sw_version` without letting older replays overwrite newer state. Optional
fields do not erase existing values when the event does not provide them.

## Q14: Why validate `wan_status` if the current table does not store it?

Validation proves the payload is a real WAN status event, not just arbitrary
JSON with a serial number. The current read model stores only fields it already
has, while the event contract remains stricter and ready for a future schema
expansion.

## Q15: What is a poison message?

A poison message is a record that will not succeed if retried unchanged. In
this project, examples include invalid JSON, wrong schema version, missing
device identity, key/device mismatch, missing timestamp, or unsupported topic.

## Q16: Which failures should retry?

Transient infrastructure failures should retry, such as temporary MySQL
unavailability, timeout, or network interruption. Payload contract failures
should not retry because time will not make malformed JSON valid.

## Q17: Why add a dead-letter topic?

Without a dead-letter path, one poison message can block later valid messages
in the same partition. Dead-letter publishing preserves the failed payload and
its metadata while letting the consumer commit the original offset and continue.

## Q18: When is it safe to commit a dead-lettered message?

Only after the dead-letter event is published successfully. Then the original
payload is not silently lost; it has moved to an operational topic for
inspection, replay, or manual repair.

## Q19: What if dead-letter publishing fails?

The handler returns an error and the original offset is not committed. That may
cause redelivery, but it avoids losing both the original event and the
dead-letter record.

## Q20: What metrics did you add?

There are two layers. Consumer progress metrics record last consumed offset,
last committed offset, message age, and reader-reported lag when available.
Processing metrics count success, retries, errors, dead-letter outcomes, and
duration by low-cardinality labels.

## Q21: Why avoid device id as a metric label?

Device ids are high-cardinality. Adding them to Prometheus labels can create a
large number of time series and hurt the monitoring system. Device-level detail
belongs in logs, dead-letter payloads, and database records.

## Q22: How do you check true consumer lag?

Use the broker view:

```powershell
kafka-consumer-groups.sh --bootstrap-server <broker> --describe --group cpemon-writer
```

The important values are `CURRENT-OFFSET`, `LOG-END-OFFSET`, and `LAG`.
Application metrics are useful, but the broker view is authoritative.

## Q23: What do the structured logs add?

They make one-event investigation possible. Logs include stable fields such as
event name, result, topic, key, partition, offset, attempt count, duration,
failure kind, and error text. Metrics show aggregate health; logs explain one
specific failure.

## Q24: How did you unit test this without Kafka?

I used fake consumers, fake readers, fake SQL executors, and fake publishers.
That tests decode, routing, validation, idempotent writes, handler errors,
commit behavior, retry decisions, dead-letter behavior, and shutdown edges
without depending on broker networking or topic state.

## Q25: What belongs in integration validation?

Integration validation proves the deployed chain: Kafka topic, consumer group
assignment, produced message, writer log, MySQL `cpe_status` update,
`cpe_status_history` record, offset progress, metrics, and API read response.

## Q26: Why does `cpemon-api` not need Kafka code?

The API reads the MySQL read model. Kafka is part of the write path that keeps
that read model updated. Keeping the API independent from Kafka avoids coupling
read availability to broker availability.

## Q27: What is the rollback plan?

Set `KAFKA_CONSUMER_ENABLED=false` and redeploy or restart `cpemon-writer`.
That stops the Kafka consumer loop while preserving the existing baseline path
and the deployed config/code for investigation.

## Q28: What was intentionally deferred?

Exactly-once Kafka transactions, schema registry enforcement, removal of the
old MySQL queue baseline, live CI cluster tests, and a production managed Kafka
decision are deferred. The story proves the consumer boundary first.

## Q29: How would you debug "Kafka messages are produced but API status does not change"?

1. Confirm the producer wrote to the expected topic with the expected key.
2. Check `cpemon-writer` has `KAFKA_CONSUMER_ENABLED=true`.
3. Inspect consumer group assignment and lag for `cpemon-writer`.
4. Search writer logs for processing, retry, dead-letter, or DB errors.
5. Query MySQL `cpe_status` and `cpe_status_history` for the device.
6. Call `GET /api/cpe/:sn` and compare the JSON to the database row.

## Q30: How would you explain this as a STAR story?

Situation: CPEmon had an MVP MySQL queue boundary that worked but did not give
strong event-platform behavior.

Task: Move the writer side toward Kafka without breaking the existing system.

Action: I introduced a consumer abstraction, configured a disabled-by-default
Kafka path, mapped heartbeat and WAN events into idempotent MySQL writes,
committed offsets only after success, added retries and dead-letter handling,
and documented validation and rollback.

Result: The project now has a testable Kafka consumer path with clear delivery
semantics, operational visibility, and interview-ready evidence for why the
migration is safe and incremental.

## Resume Version

Refactored `cpemon-writer` into a Kafka consumer behind a feature flag by
adding a broker-independent consumer interface, consumer group config,
idempotent MySQL write models, explicit post-processing offset commits,
bounded retry/dead-letter behavior, low-cardinality metrics, structured logs,
unit tests, integration runbooks, and rollback documentation.

