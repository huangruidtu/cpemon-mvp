# ADR: acs-ingest Kafka Producer Migration

## Status

Accepted for Story 15 implementation.

## Context

Before this migration, `acs-ingest` accepted ACS webhook payloads and stored
raw ingest events in the database-backed `ingest_events` queue. That path is
simple and durable, but downstream workflows remain coupled to database polling
and cannot subscribe to normalized device events.

Story 15 introduces Kafka publishing for normalized CPEmon events:

* `cpemon.device.heartbeat.v1`
* `cpemon.wan.status.v1`

The migration must preserve the existing intake behavior while creating an
event-driven boundary for later consumers.

## Decision

`acs-ingest` will publish normalized Kafka events through the small
`EventPublisher` interface after a valid webhook has been persisted to
`ingest_events`.

The producer remains behind `KAFKA_PRODUCER_ENABLED` so environments can deploy
the code before enabling live Kafka publication.

## Rationale

Why Kafka:

* Decouples ingestion from downstream processing.
* Lets multiple consumers subscribe without adding database coupling.
* Gives stable topic/key contracts for device events.
* Supports later replay, analytics, alerting, and consumer-specific scaling.

Why an interface:

* Keeps webhook parsing and validation independent from Kafka client details.
* Enables unit tests with fake publishers.
* Keeps future producer replacements possible without rewriting ingest logic.

Why persist before publish:

* The database remains the durable intake record.
* Kafka publishing happens only after the webhook has been validated and stored.
* A publish failure is explicit and observable when the producer is enabled.

Why feature flag:

* Existing deployments can keep enqueue-only behavior.
* Kafka rollout can be staged by environment.
* Rollback can disable publishing without reverting code.

## Consequences

Positive:

* Downstream consumers can be added without changing `acs-ingest`.
* Event contracts are normalized and versioned.
* Unit tests remain broker-free.
* Logs and metrics expose the producer handoff.

Tradeoffs:

* The current producer is at-least-once, so consumers must be idempotent.
* If a write is ambiguous, retry may create duplicates.
* Live Kafka validation requires cluster state, topics, and broker connectivity.
* Consumer behavior remains out of scope until later stories.

## Current Boundary

In scope now:

* Event schemas.
* `EventPublisher` interface.
* Kafka producer adapter.
* App config and Helm wiring.
* `acs-ingest` publish wiring.
* Retry/error handling.
* Producer logs and metrics.
* Unit tests and integration validation runbook.

Out of scope now:

* Kafka consumers.
* Exactly-once delivery.
* Schema registry.
* Dead-letter publishing implementation.
* Automated live-cluster integration test in CI.

## Operational References

* `ops/runbooks/acs-ingest-kafka-producer-validation.md`
* `ops/runbooks/acs-ingest-kafka-producer-operations.md`
* `docs/knowledge/acs-ingest-kafka-producer-refactor.md`
