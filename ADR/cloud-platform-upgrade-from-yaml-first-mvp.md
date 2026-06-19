# ADR: From YAML-first MVP to Cloud Platform Edition

- Status: Proposed
- Date: 2026-06-18
- Decision owner: Huang Rui
- Related components: k8s manifests, Helm, Argo CD, EKS, Terraform, CI/CD

## Context

The MVP intentionally uses raw Kubernetes YAML and manual deployment commands because the first goal was clarity. A reviewer can open `k8s/` and see Deployments, Services, Ingress, PDBs, NetworkPolicies, monitoring resources, and cron jobs directly.

That choice was right for the MVP, but the platform upgrade has a different goal. Step 1 needs a repeatable cloud deployment model with environment reuse, drift control, reviewable infrastructure changes, and a clearer promotion path.

The current model has several limitations:

- Raw YAML is readable but becomes repetitive across environments.
- Manual `kubectl apply` can create drift.
- There is no GitOps reconciler enforcing desired state.
- Runtime secrets and configuration are not cleanly separated.
- Release promotion is not standardized.
- Validation does not yet include full manifest, policy, and Terraform gates.

## Decision

Step 1 will evolve CPEmon from a YAML-first MVP into a Cloud Platform Edition baseline:

- Terraform manages AWS, EKS, IAM, ECR, and OIDC foundations.
- Helm packages CPEmon services and selected platform components.
- Argo CD reconciles desired state from Git.
- PR checks validate application code, images, manifests, policies, and Terraform plans.
- External Secrets Operator moves secret delivery out of raw app manifests.
- Existing raw YAML remains useful as source material during migration, but it should no longer be the final deployment interface.

## Alternatives

1. Keep raw YAML and manual apply.

   Pros:

   - Simple and transparent.
   - Matches the current MVP.

   Cons:

   - Does not solve drift, promotion, environment reuse, or platform governance.

2. Use Kustomize only.

   Pros:

   - Good for overlays and native to `kubectl`.
   - Less templating complexity than Helm.

   Cons:

   - Does not provide a package/release model as clearly as Helm for this Step 1 story.
   - Still needs a GitOps controller and broader CI gates.

3. Move directly to a full self-service platform.

   Pros:

   - More ambitious developer experience.

   Cons:

   - Too large for Step 1.
   - Risks mixing foundation work with Step 2 platform API and portal work.

## Consequences

Positive consequences:

- Git becomes the source of truth for cluster state.
- Pull requests become the standard review point for app and infrastructure changes.
- The platform is easier to explain as a production-style evolution of the MVP.
- Step 2 can build self-service workflows on top of a stable foundation.

Trade-offs:

- Helm, Argo CD, and Terraform add operational surface area.
- Documentation and developer golden path become more important.
- The repo needs a migration period where raw YAML and Helm may coexist.
