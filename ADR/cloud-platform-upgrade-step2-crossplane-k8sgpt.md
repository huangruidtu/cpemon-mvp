# ADR: Why Crossplane and k8sGPT Are Step 2

- Status: Proposed
- Date: 2026-06-18
- Decision owner: Huang Rui
- Related components: Crossplane, k8sGPT, platform resource provisioning, operational insight

## Context

The Step 1 scope already includes EKS, Terraform, ECR, GitHub OIDC, federated human AWS access, Helm, Argo CD, Kafka, Argo Rollouts, Prometheus analysis, External Secrets Operator, Trivy, Kyverno, OpenCost, Renovate, PR gates, Terraform plans, pre-commit hooks, kubeconform, kube-linter, and developer documentation.

Crossplane would add a second major layer: developers or platform maintainers could request infrastructure through Kubernetes-style platform APIs instead of only changing Terraform modules directly.

k8sGPT can help summarize operational signals and point maintainers toward likely Kubernetes issues, but it is more useful after the baseline cluster, GitOps, policy, and monitoring paths are stable.

Both tools are valuable, but they belong to a more advanced platform stage. Step 1 should first prove the foundation: managed Kubernetes, GitOps, infrastructure as code, event buffering, CI security gates, secret management, cost visibility, and dependency automation.

## Decision

Crossplane and k8sGPT will be deferred to Step 2.

The intent is not to reject these tools. The intent is to sequence them correctly:

- Crossplane represents developer self-service and platform API capabilities.
- k8sGPT represents assisted operational diagnosis and a first-pass Kubernetes troubleshooting layer.
- Both are stronger after the Step 1 operating model is stable.

Step 1 will prepare for Step 2 by:

- Standardizing GitOps and Helm conventions.
- Documenting a developer golden path.
- Keeping Terraform modules organized enough to later expose selected resources through a platform API.
- Keeping observability signals and operational runbooks understandable enough for k8sGPT to complement them later.

## Alternatives

1. Add Crossplane in Step 1.

   Pros:

   - Strong self-service infrastructure story.
   - Good platform engineering signal.

   Cons:

   - Adds another control plane before the basic EKS/GitOps baseline is proven.
   - Makes incident and debugging paths harder during the first migration.
   - Risks turning the platform team into maintainers of two provisioning models before the Terraform baseline is stable.

2. Add k8sGPT in Step 1.

   Pros:

   - Useful operational insight during troubleshooting.

   Cons:

   - Adds another operational tool before the core monitoring and GitOps baseline is proven.
   - Risks presenting AI-assisted diagnosis as a replacement for clear dashboards, alerts, and runbooks.

3. Build a full developer portal immediately.

   Pros:

   - Strong developer experience story.

   Cons:

   - Too broad for the current MVP upgrade.

## Consequences

Positive consequences:

- Step 1 stays focused on the cloud/GitOps foundation.
- Step 2 has a clear, limited story: add platform resource provisioning and assisted operational insight.
- Crossplane can be introduced with Terraform, GitOps, and deployment conventions already in place.
- k8sGPT can become a first-pass diagnostic assistant after the platform already emits useful Kubernetes, rollout, and observability signals.
- The platform team avoids becoming a bottleneck too early by first standardizing the foundation and then exposing selected capabilities through self-service.

Trade-offs:

- Step 1 will not yet provide a platform API or k8sGPT-assisted troubleshooting.
- Developers will still use pull requests and GitOps workflows directly.
- Self-service and assisted diagnosis are delayed until the platform foundation is clearer.
