# ADR: cpemon-writer Kafka Consumer Migration

## Status

Accepted for Story 16 implementation.

## Context

The original CPEmon MVP used a database-backed `ingest_events` queue and a
writer loop that polled MySQL. That was a reasonable MVP choice because it kept
the demo small and easy to run.

The cloud-platform upgrade introduces Kafka as the event-buffering boundary.
`acs-ingest` now has a producer path for normalized events:

* `cpemon.device.heartbeat.v1`
* `cpemon.wan.status.v1`

`cpemon-writer` needs to consume those events and update the existing MySQL read
model used by `cpemon-api`.

## Decision

`cpemon-writer` will add a Kafka consumer path behind
`KAFKA_CONSUMER_ENABLED`.

When enabled, the writer:

1. Joins consumer group `cpemon-writer`.
2. Subscribes to heartbeat and WAN status topics.
3. Converts Kafka records into `ConsumedEvent`.
4. Routes events by topic.
5. Validates and writes MySQL read-model rows.
6. Retries transient failures with bounded backoff.
7. Publishes poison or exhausted messages to `cpemon.deadletter.v1`.
8. Commits offsets only after successful processing or successful dead-letter
   publication.

The existing MySQL polling loop remains available as the baseline until the
Kafka path is proven live and intentionally promoted by environment.

## Rationale

Why Kafka consumer:

* Decouples ingestion from writer processing.
* Lets writer replicas share topic partitions through a consumer group.
* Makes lag, replay, and dead-letter behavior explicit.
* Aligns CPEmon with an event-driven cloud-platform architecture.

Why keep the API unchanged:

* `cpemon-api` already reads `cpe_status`.
* Kafka belongs in the write path into the read model, not in the API read path.
* Keeping the API unchanged reduces migration blast radius.

Why feature flag:

* Environments can deploy the code before enabling live consumption.
* Rollback is operational: set `KAFKA_CONSUMER_ENABLED=false`.
* The MySQL queue path can remain the known baseline during validation.

Why at-least-once:

* The consumer commits offsets after MySQL writes, not before.
* A crash after DB write but before commit can replay an event.
* Therefore the MySQL writes are idempotent and replay-safe.

Why dead-letter:

* Infinite retries can block a Kafka partition behind one poison message.
* Poison messages should be preserved for inspection instead of silently
  acknowledged or retried forever.
* Dead-letter publication is the point where committing the original message is
  safe.

## Consequences

Positive:

* Writer processing can scale by partition through the `cpemon-writer` group.
* Consumer reliability decisions are explicit and testable.
* Metrics and logs identify topic, partition, offset, retry, dead-letter, and
  processing latency context.
* API consumers continue using the same read endpoint.

Tradeoffs:

* The system is at-least-once, not exactly-once.
* Duplicate delivery is expected after retry or crash boundaries.
* Live proof requires Kafka, `cpemon-writer`, MySQL, and `cpemon-api` running.
* The current implementation uses application-level JSON contracts rather than
  a schema registry.

## Current Boundary

In scope now:

* `EventConsumer` interface and `ConsumedEvent` envelope.
* Kafka consumer adapter with explicit commit timing.
* Config and Helm wiring.
* Heartbeat and WAN status topic subscription.
* MySQL write model updates.
* Retry and dead-letter handling.
* Consumer lag/progress metrics.
* Processing metrics and structured logs.
* Broker-free unit tests.
* Kafka-to-DB and API validation runbooks.

Out of scope now:

* Exactly-once Kafka transactions.
* Schema registry enforcement.
* Automated live-cluster integration test in CI.
* Removing the old MySQL queue baseline.
* Domain-specific dead-letter topics beyond the shared Step 1 topic.

## Rollout And Rollback

Rollout:

1. Deploy with `KAFKA_CONSUMER_ENABLED=false`.
2. Verify config, topics, and DB connectivity.
3. Enable Kafka consumer in one environment.
4. Run Kafka-to-DB validation.
5. Run API status validation.
6. Watch lag, processing metrics, dead-letter metrics, and logs.

Rollback:

1. Set `KAFKA_CONSUMER_ENABLED=false`.
2. Redeploy or restart `cpemon-writer`.
3. Confirm `event=writer_kafka_consumer result=start` no longer appears.
4. Continue using the existing DB queue baseline.

## Operational References

* `ops/runbooks/cpemon-writer-kafka-consumer-operations.md`
* `ops/runbooks/cpemon-writer-kafka-consumer-group.md`
* `ops/runbooks/cpemon-writer-kafka-consumer-lag.md`
* `ops/runbooks/cpemon-writer-kafka-to-db-validation.md`
* `ops/runbooks/cpemon-api-kafka-updated-status-validation.md`
* `docs/knowledge/cpemon-writer-kafka-consumer-refactor.md`
