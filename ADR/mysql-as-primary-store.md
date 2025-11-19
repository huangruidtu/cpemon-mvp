# ADR: Using MySQL as the Primary Data Store

- Status: Accepted
- Date: 2025-11-19
- Decision owner: Huang Rui
- Related components: MySQL, cpemon-api, acs-ingest, cpemon-writer

## Context

The MVP-CPEmon platform needs to store several types of data:

- **CPE state**: last heartbeat, WAN IP, software version, timestamps.
- **ACS events**: webhook payloads, event timestamps, basic metadata.
- **Queues**: intermediate buffering between HTTP ingest and background processing.

There are many possible storage technologies that could be used:

- Relational databases (MySQL, PostgreSQL).
- Document/datastore solutions (MongoDB, Couchbase).
- Time-series databases (for metrics-style data).
- Stream storage (Kafka, Pulsar) with separate sinks.

In this lab, MySQL is already available and familiar:

- Easy to run in a small kubeadm cluster.
- Well-known operational characteristics.
- Works well for both transactional data and simple queue tables.

At the same time, the MVP is **not** aiming to benchmark extreme scale or design a fully polyglot persistence layer. The main goal is to:

- Keep state management understandable.
- Make it easy to inspect data with simple SQL queries.
- Support the demo scenarios (heartbeats, ACS events, backlogs).

## Decision

For the MVP, I decided to use **MySQL as the single primary data store** for CPEmon:

- **Queue tables**:
  - `cpemon-api` and `acs-ingest` append events to dedicated queue tables.
  - `cpemon-writer` polls and processes these rows, updating their status.
- **Business tables**:
  - `cpemon-writer` writes consolidated CPE state and ACS event summaries into normalised tables.
- **Supporting queries**:
  - Read models and views can be added on top for dashboards and ad-hoc inspection.

Other storage components stay **supporting-only**:

- MinIO/S3: used for MySQL dumps and Velero backups.
- Elasticsearch: used only for logs, not for primary data.

## Alternatives

1. **PostgreSQL as the primary store**

   - Pros:
     - Richer data types and features (JSONB, window functions, etc.).
     - Very strong candidate for modern applications.

   - Cons:
     - For this MVP, it would add variety without clear additional value.
     - MySQL is already enough for the schemas I need.
     - Reviewer benefit is limited: the important part is *that* I use a relational store, not *which one*.

2. **Polyglot persistence (multiple specialised stores)**

   - Example:
     - MySQL for state,
     - Kafka for queues,
     - TSDB for time-series CPE metrics,
     - Elasticsearch for search.

   - Pros:
     - More realistic for a large, mature telco platform.
     - Each workload type uses an optimal data store.

   - Cons:
     - Much more complex to explain and operate in a small lab.
     - Harder for reviewers to “follow the data” across many systems.
     - High overhead for an interview demo.

3. **NoSQL / document store as primary**

   - Pros:
     - Flexible schema for evolving payloads.
   - Cons:
     - For this MVP, the data has a fairly regular structure (CPEs, events).
     - Requires more explanation around consistency and modelling.
     - Does not bring a clear benefit compared to a simple relational model here.

## Consequences

- **Pros**
  - A **single source of truth** for CPEmon state and queues:
    - Easier to reason about and debug.
    - Easy to verify demo scenarios using plain SQL.
  - Simplifies the architecture:
    - One relational database to deploy and back up.
    - Other storage systems can be discussed as future enhancements.
  - Fits well with:
    - MySQL-based queueing (see “Not Using Kafka in the MVP” ADR),
    - Velero + MinIO for backup/restore demos.

- **Cons**
  - Scalability is ultimately tied to MySQL’s write throughput and schema design.
  - No natural separation between “operational” and “analytical” stores.
  - In a real telco with millions of CPEs, I would likely add Kafka and other specialised datastores.

Overall, this decision keeps the MVP focused and easy to understand.  
In interviews, I can clearly explain the trade-off and also describe how I would evolve it (e.g. introducing Kafka and dedicated datastores) for larger-scale production deployments.

