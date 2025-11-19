# ADR: YAML-first Manifests Instead of Helm Charts

- Status: Accepted
- Date: 2025-11-19
- Decision owner: Huang Rui
- Related components: k8s/ manifests, cpemon services, observability stack

## Context

There are several ways to manage Kubernetes manifests:

- Raw YAML files committed directly in the repo.
- Kustomize overlays.
- Helm charts (templated manifests with values files).
- More advanced operators or GitOps-based setups.

In production, it is common to:

- Use Helm or Kustomize to manage multiple environments (dev, staging, prod).
- DRY up repetitive manifest patterns.
- Integrate with GitOps tools (Argo CD, Flux, etc.).

For this **MVP project**, the goals are different:

- A reviewer (e.g. hiring manager, SRE lead) should be able to:
  - Open `k8s/` and immediately see what each Deployment, Service, Ingress, etc. does.
  - Understand the architecture without first learning a templating system.
- The cluster is a single lab environment — no complex multi-env matrix is required.
- The focus is on **clarity and teaching value**, not on advanced packaging.

## Decision

For the MVP, I chose a **YAML-first approach**:

- Store **plain Kubernetes YAML** under `k8s/`, organised by component/area:
  - `k8s/cpemon/` for core CPEmon services.
  - `k8s/monitoring/`, `k8s/logging/`, `k8s/cron/`, etc.
- Keep manifests as readable as possible:
  - Add comments where helpful (e.g. why a ServiceMonitor exists).
  - Avoid deep templating logic that hides what is actually applied.
- Accept a small amount of duplication in exchange for:
  - Simpler mental model.
  - Easier debugging when something goes wrong.

Helm and Kustomize are treated as **possible future improvements**, not mandatory for this MVP.

## Alternatives

1. **Use Helm charts from the beginning**

   - Pros:
     - Powerful for managing multiple environments and values.
     - A standard tool in many organisations.
   - Cons:
     - Adds another layer that reviewers must mentally parse:
       - `values.yaml` + templates instead of a single Deployment YAML.
     - For a small, interview-focused repo, the extra abstraction does not pay off.
     - Debugging often requires rendering templates (`helm template`) anyway.

2. **Use Kustomize overlays (base + overlays)**

   - Pros:
     - Native to `kubectl`.
     - Good for layering small environment differences.
   - Cons:
     - Still adds indirection when a reviewer just wants to “see the manifest”.
     - This MVP runs in essentially one environment (a lab cluster).

3. **Use no manifests at all (only `kubectl create` / imperative)**

   - Pros:
     - Very quick to start.
   - Cons:
     - No Git history of the desired state.
     - Impossible to review or reuse easily.
     - Not acceptable for a demo that is supposed to show good SRE practices.

## Consequences

- **Pros**
  - Lower cognitive load for reviewers:
    - They can open a single YAML file and see **exactly** what is being applied.
    - No need to understand Helm templating or overlay mechanics.
  - Easier to explain the architecture in interviews:
    - “Here is the Deployment for `cpemon-api`, here is its Service, here is its Ingress.”
  - Simpler debugging:
    - `kubectl apply -f` directly matches what is in `git`.
    - No hidden generated files.

- **Cons**
  - Some repetition across manifests (e.g. labels, common annotations).
  - If the project grows into multiple environments, templates or overlays will be needed later.
  - Does not showcase Helm/Kustomize skills directly (those would be explained verbally).

Overall, the YAML-first choice aligns with the MVP’s teaching and demo goals:  
**make the manifests as transparent as possible**, so the main focus stays on the architecture, observability, and operational stories rather than on templating mechanics.

