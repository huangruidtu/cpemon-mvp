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

### How can you test this without Kafka?

Use a fake `EventConsumer` that feeds `ConsumedEvent` values into the handler.
That tests routing, error propagation, and future write behavior without broker
setup.

## Resume Bullet

Defined the writer-side Kafka consumer boundary with a broker-independent
`EventConsumer` interface and `ConsumedEvent` envelope, enabling testable
consumer logic with explicit topic, key, payload, partition, offset, context,
handler error, and close lifecycle behavior.
