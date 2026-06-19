# ADR: Why EKS, Terraform, GitOps, and Kafka

- Status: Proposed
- Date: 2026-06-18
- Decision owner: Huang Rui
- Related components: EKS, Terraform, Argo CD, Kafka, ECR, GitHub OIDC

## Context

The current CPEmon MVP runs on a lab Kubernetes cluster and uses MySQL queue tables as a simple durable buffer. This keeps the MVP small and demonstrable, but Step 1 is meant to show a cloud platform upgrade path.

The upgraded platform needs:

- Managed Kubernetes operations.
- Reviewable infrastructure changes.
- Continuous reconciliation from Git.
- A stronger event buffer for CPE and ACS events.
- Traceable image build and deployment flow.
- A clean path from pull request to running workload.

## Decision

Step 1 will use:

- EKS as the managed Kubernetes target.
- Terraform as the infrastructure as code tool for AWS, EKS, IAM, ECR, OIDC, and supporting resources.
- GitOps with Argo CD so cluster state is reconciled from Git.
- Kafka as the durable event buffer between ingest services and downstream writers.
- ECR as the image registry.
- GitHub OIDC for short-lived AWS credentials in CI.
- Federated human access through AWS IAM Identity Center or an enterprise IdP for AWS console/CLI login.

MySQL remains the business data store in Step 1 unless a later story explicitly changes the data layer. Kafka replaces the MVP's MySQL queue role, not the business tables.

## Alternatives

1. Self-managed Kubernetes on VMs.

   Pros:

   - Similar to the current lab.
   - Lower cloud dependency.

   Cons:

   - Does not demonstrate managed Kubernetes operations.
   - More manual control plane maintenance.

2. Manual Terraform plus manual kubectl deploy.

   Pros:

   - Infrastructure becomes reviewable.

   Cons:

   - Application deployment drift remains unsolved.

3. Keep MySQL queue tables instead of Kafka.

   Pros:

   - Fewer moving parts.
   - Easier local operation.

   Cons:

   - Weaker replay, partitioning, consumer scaling, and event retention story.

4. Use a fully managed production Kafka service immediately.

   Pros:

   - Strong managed Kafka story.

   Cons:

   - Higher cost and complexity for Step 1.
   - Better treated as a later hardening decision.

## Consequences

Positive consequences:

- EKS gives the platform a realistic cloud target.
- Terraform makes infrastructure reviewable and repeatable.
- Argo CD removes manual apply as the normal deployment path.
- Kafka gives CPEmon a clearer event-driven architecture.
- GitHub OIDC and federated human access reduce long-lived cloud credential risk.

Trade-offs:

- More components must be operated and documented.
- Kafka introduces topic, partition, retention, and consumer lag decisions.
- CI and GitOps conventions must be kept simple enough for a small project.
