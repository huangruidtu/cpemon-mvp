# ADR: Not Using Kafka in the MVP

- Status: Accepted
- Date: 2025-11-18
- Decision owner: Huang Rui
- Related components: cpemon-api, acs-ingest, cpemon-writer, MySQL

## Context

In previous work I have used Kafka for building streaming pipelines and decoupling producers/consumers.  
For this MVP, I wanted to simulate an ISP-style CPE monitoring platform (CPEmon), but:

- The lab environment has limited resources (a small kubeadm cluster + one external VM).
- The primary goal is to **show a complete story end-to-end** (CPE → ACS → ingest → DB → dashboards), not to optimise for massive scale.
- Introducing Kafka would require:
  - Zookeeper or KRaft-based brokers (extra Pods / VMs, disks, networking).
  - Additional configuration (topics, partitions, retention, security).
  - More operational surface area to explain in a short demo.

At the same time, the event rate in this lab is relatively low (simulated CPEs, demo-level webhook traffic), and we already have MySQL as the primary data store.

## Decision

For the MVP, I decided **not to use Kafka** and instead:

- Use **MySQL-based queue tables** as the buffering mechanism between:
  - ingress services (`cpemon-api`, `acs-ingest`)
  - and the background consumer (`cpemon-writer`).
- Implement a simple “append to queue → mark as processed” pattern in MySQL:
  - Request handlers insert rows into queue tables.
  - `cpemon-writer` polls and processes them, then updates status.

This keeps the ingest pipeline simpler and easier to reason about for reviewers.

## Alternatives

1. **Full Kafka-based pipeline**

   - Pros:
     - Natural decoupling between producers and consumers.
     - Built-in persistence and replay.
     - Easier to scale out consumers for higher throughput.

   - Cons:
     - Requires running one or more Kafka brokers (plus Zookeeper or KRaft).
     - More moving parts to configure and monitor.
     - Harder to fit into a small lab cluster.
     - Demo time is limited: explaining Kafka + CPEmon + observability could overwhelm reviewers.

2. **In-memory queues (e.g. Go channels or Redis lists)**

   - Pros:
     - Very simple to implement.
     - No extra database schema.

   - Cons:
     - In-memory queues are not durable across Pod restarts.
     - Redis would add another external dependency.
     - Harder to inspect from SQL / dashboards.

3. **Direct synchronous writes (no queue)**

   - Pros:
     - Simplest code path (ingress handlers directly update business tables).
   - Cons:
     - Less flexibility for retries / dead-letter handling.
     - Harder to demonstrate “backlog” and consumer failure scenarios.

## Consequences

- **Pros**
  - Much easier to set up in a small lab (only MySQL, no Kafka cluster).
  - Simpler to explain in interviews:
    - I can still talk about **where Kafka would fit** in a real system.
    - But the MVP remains readable and reproducible.
  - Still supports:
    - basic buffering,
    - dead-letter logic,
    - backlog demos (by scaling `cpemon-writer` down to zero).

- **Cons**
  - Scalability is bounded by MySQL throughput and polling behaviour.
  - No native log compaction, partitions, or consumer groups.
  - Less realistic for truly large-scale telco workloads.

Overall, this trade-off is acceptable for an **MVP demo project** whose main goal is to show architecture thinking, observability, and operational practices, not to benchmark Kafka.

