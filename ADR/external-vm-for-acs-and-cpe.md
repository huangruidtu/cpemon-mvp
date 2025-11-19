# ADR: Running ACS and CPE Simulators on an External VM

- Status: Accepted
- Date: 2025-11-19
- Decision owner: Huang Rui
- Related components: vm3 (GenieACS + CPE simulators), Kubernetes cluster, ingress-nginx

## Context

The MVP-CPEmon lab environment consists of:

- A small Kubernetes cluster (1 control-plane + 1 worker).
- An additional VM (`vm3`) used to host:
  - GenieACS (TR-069 ACS).
  - CPE heartbeat simulators (Docker containers).

A fully “cloud-native only” design could put everything inside the Kubernetes cluster:

- GenieACS as a Deployment + Service.
- CPE simulators as Pods.

However, in many **real-world telco environments**:

- Existing ACS / OSS / BSS systems often run outside Kubernetes.
- New platforms have to integrate with these systems via HTTP, gRPC, message buses, etc.
- The more realistic story is **“plugging a new observability/ingest layer into an existing ACS”**, not rewriting the ACS itself.

The lab also has limited resources; moving everything into the cluster would increase the load and slightly reduce the realism of the topology.

## Decision

For this MVP, I decided to:

- Keep **GenieACS and the CPE simulators on an external VM (`vm3`)**.
- Let `vm3` communicate with the Kubernetes cluster via:
  - `https://api.local/cpe/heartbeat` (CPE heartbeats to `cpemon-api`).
  - `https://api.local/acs/webhook` (GenieACS webhooks to `acs-ingest`).
- Expose these entrypoints through ingress-nginx, just like a real external system would see them.

In other words:

> **Kubernetes runs the new CPEmon platform; vm3 represents existing “legacy” ACS infrastructure.**

## Alternatives

1. **Run GenieACS and CPE simulators inside the Kubernetes cluster**

   - Pros:
     - All components are in one place.
     - Easier to manage using the same deployment patterns (Deployments, Services, etc.).
   - Cons:
     - Less realistic: many companies don’t (yet) run ACS inside K8s.
     - Harder to tell the integration story: “new platform integrates with old system”.
     - Slightly higher resource usage on the small cluster.

2. **Run everything on VMs / Docker Compose (no Kubernetes)**

   - Pros:
     - Simpler from a pure “run it locally” perspective.
     - Single host or a small set of hosts.

   - Cons:
     - Cannot demonstrate Kubernetes-native concepts:
       - Deployments, Services, Ingress, ServiceMonitors, etc.
     - Loses the main “cloud-native SRE” angle of the project.
     - Harder to show HA, observability and backup patterns in a modern way.

3. **Hybrid but with more components outside K8s**

   - Example: run MySQL, Elasticsearch, etc. on separate VMs.

   - Pros:
     - Closer to some brownfield environments.
   - Cons:
     - More moving parts to provision and document.
     - Too heavy for an MVP / interview-focused project.

## Consequences

- **Pros**
  - The topology feels realistic:
    - `vm3` acts as “existing ACS + lab CPEs” in a telco network.
    - Kubernetes hosts the new ingest / monitoring / observability stack.
  - Clear integration points:
    - Ingress routes mirror what a real ACS would talk to.
    - Easy to reason about network paths and DNS (`api.local`).
  - Good interview story:
    > “I didn’t pretend the world starts at Kubernetes.  
    > I explicitly modelled how a new CPEmon platform would integrate with an existing ACS running somewhere else.”

- **Cons**
  - Local setup is slightly more complex:
    - Requires one extra VM with Docker, `/etc/hosts` changes, etc.
  - Some automation (e.g. full cluster + vm3 bring-up) is out of scope for the MVP.
  - Not all aspects of production networking (VPNs, firewalls, etc.) are represented.

Overall, placing ACS and CPE simulators on an external VM gives a much stronger narrative:  
**“new Kubernetes-based monitoring platform integrating with an existing ACS”**, which is a very common real-world scenario.

