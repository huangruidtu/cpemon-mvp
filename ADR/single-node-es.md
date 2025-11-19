# ADR: Single-node Elasticsearch for Logs

- Status: Accepted
- Date: 2025-11-18
- Decision owner: Huang Rui
- Related components: Filebeat, Elasticsearch, Kibana, cpemon services

## Context

The MVP-CPEmon platform needs basic log observability:

- Collect logs from key namespaces (`cpemon`, `genieacs`, `ingress-nginx`, etc.).
- Make them searchable in Kibana.
- Support simple demo use cases:
  - Search by namespace/pod/container.
  - Filter logs by CPE serial number or request_id.

In production, an ISP-like platform would typically run:

- A **multi-node Elasticsearch cluster** with:
  - multiple data nodes across AZs,
  - dedicated master nodes,
  - snapshot/restore,
  - index lifecycle management.

However, this MVP runs on a small lab cluster with:

- Limited CPU, memory and storage.
- Only a few nodes.
- A focus on **demoing concepts**, not production-scale log throughput or HA.

## Decision

For the MVP, I decided to run **a single-node Elasticsearch instance**:

- Deployed in the `logging` namespace.
- Backed by a single PersistentVolume.
- Ingested primarily by Filebeat from the K8s nodes / pods.

There is **no ES clustering or shard reallocation across nodes** in this setup.

## Alternatives

1. **Three-node Elasticsearch cluster (production-style)**

   - Pros:
     - Higher availability (lost one node ≠ lost cluster).
     - Better resilience and capacity for larger log volumes.
     - Closer to a real-world telco observability stack.

   - Cons:
     - Resource-heavy in a small lab.
     - More configuration (discovery, node roles, JVM tuning).
     - Increases noise when the main goal is to demo CPEmon, not ES internals.

2. **No Elasticsearch (logs only via `kubectl logs` or Loki)**

   - Pros:
     - Much simpler (or, with Loki, more lightweight).
     - Less resource usage.

   - Cons:
     - Harder to demonstrate Kibana-style querying (e.g. filter by namespace, pod, CPE SN).
     - Reviewers are often familiar with the ELK pattern; skipping ES loses that connection.
     - Loki would introduce another stack to explain.

3. **Hosted / managed Elasticsearch**

   - Pros:
     - Offloads cluster management.
   - Cons:
     - Not always available in a local lab.
     - Adds dependency on external cloud accounts.
     - Demo becomes less self-contained.

## Consequences

- **Pros**
  - Keeps the observability story simple and self-contained.
  - Easy to install and tear down on a small cluster.
  - Good enough for:
    - typical demo traffic,
    - searching by labels/fields,
    - linking logs with metrics and dashboards.

- **Cons**
  - **No high availability**: if the single ES Pod or node fails, logs become temporarily unavailable.
  - Limited capacity and durability compared to a real ES cluster.
  - Not a production recommendation; it’s clearly a **MVP-only compromise**.

This decision matches the overall philosophy of the project:  
focus on **clarity and completeness of the story** over full production-grade scaling and HA.

