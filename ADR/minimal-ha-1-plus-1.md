# ADR: 1+1 HA Strategy (Minimal Redundancy)

- Status: Accepted
- Date: 2025-11-18
- Decision owner: Huang Rui
- Related components: Kubernetes cluster, cpemon-api, cpemon-writer, ingress-nginx

## Context

High availability (HA) is important for a real ISP monitoring platform:

- Control plane redundancy (multiple masters).
- Multiple worker nodes across racks / AZs.
- Load balancers and storage replicated across failure domains.
- Services configured with proper PodDisruptionBudgets, anti-affinity, and replica spreads.

However, the lab environment for this MVP has:

- Limited hardware / VM resources.
- A small kubeadm cluster (e.g. **1 control-plane + 1 worker**).
- One extra VM (vm3) for GenieACS and CPE simulators.

The goal is to **demonstrate HA concepts** without trying to fully mimic a production setup.

## Decision

For the MVP, I adopted a **“1+1 minimal HA”** strategy:

- **Cluster level**
  - One control-plane node.
  - One worker node.
  - This is *not* production-grade, but enough to:
    - run workloads on a dedicated worker,
    - keep the control-plane separate from user Pods.

- **Workload level**
  - Critical services use **at least 2 replicas**, for example:
    - `cpemon-api`: `replicas=2`
    - `cpemon-writer`: `replicas=2` (when not intentionally scaled to 0 for demos)
    - `ingress-nginx` controller: at least 1–2 replicas, depending on node capacity.
  - Basic readiness/liveness probes configured so K8s can restart unhealthy Pods.

- **Demonstration focus**
  - Show that:
    - Load is automatically balanced across replicas.
    - Losing one Pod does not break the service.
    - We can still create controlled failure scenarios (e.g. scaling writer to 0) to show impact and recovery.

## Alternatives

1. **Full production-style HA**

   - Multiple control-plane nodes.
   - 3+ worker nodes, spread across different hosts / AZs.
   - More replicas and stricter Pod anti-affinity rules.

   - Pros:
     - Much closer to real-world telco deployments.
     - Survives more types of failures.

   - Cons:
     - Requires significantly more hardware/VMs.
     - More complex to set up and maintain in a personal lab.
     - Hard to explain all details in a short interview demo.

2. **Single-node cluster (all-in-one)**

   - Pros:
     - Simpler to set up.
     - Only one VM for everything.

   - Cons:
     - No separation between control-plane and workloads.
     - Any node failure = full outage.
     - Hard to talk about HA concepts credibly.

3. **Multi-node cluster but single replica per service**

   - Pros:
     - Saves resources.
     - Still has some node-level separation.

   - Cons:
     - Each critical service becomes a single point of failure.
     - Harder to demonstrate how K8s handles Pod failures.

## Consequences

- **Pros**
  - Fits into a **small lab footprint**: 1 control-plane + 1 worker + 1 external VM.
  - Still allows me to:
    - talk about replica-based HA at the application layer,
    - demo how traffic flows across multiple Pods,
    - show what happens when a single Pod or deployment is disrupted.
  - The story is easy to explain:
    > “This is not full enterprise HA, but it shows how I think about redundancy and failure modes under hardware constraints.”

- **Cons**
  - Control-plane is still a single point of failure.
  - Loss of the only worker node will bring down application workloads.
  - Does not model cross-AZ or cross-region failures.
  - Some advanced HA topics (e.g. etcd quorum, multi-master upgrades) are out of scope for this MVP.

Overall, the **1+1 minimal HA** strategy is a pragmatic compromise:
it lets me demonstrate HA principles and K8s features clearly,  
while staying within the limits of my personal lab hardware.

