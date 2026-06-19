# ADR: Why EKS, Terraform, GitOps, Kafka, ECR, and OIDC

- Status: Proposed
- Date: 2026-06-18
- Decision owner: Huang Rui
- Related components: EKS, Terraform, Argo CD, Kafka, ECR, GitHub OIDC, AWS IAM Identity Center, Renovate, CI/CD

## Context

The current CPEmon MVP runs on a lab Kubernetes cluster and uses MySQL queue tables as a simple durable buffer. This keeps the MVP small and demonstrable, but Step 1 is meant to show a cloud platform upgrade path.

EKS is selected because AWS is already the available cloud environment for this project, and practicing one managed Kubernetes platform deeply is more valuable than spreading effort across AWS, GCP, and Azure at the same time. The concepts should transfer to GKE and AKS later: managed control planes, cloud IAM, container registry integration, network/load balancer integration, and environment automation.

For a small demo, EC2 or a simple VM-based Kubernetes setup could be enough. The reason to use EKS is to practice the type of managed Kubernetes workflow that appears in larger company and production platform environments.

The upgraded platform needs:

- Managed Kubernetes operations.
- Reviewable infrastructure changes.
- Continuous reconciliation from Git.
- A stronger event buffer for CPE and ACS events.
- Traceable image build and deployment flow.
- A clean path from pull request to running workload.
- A safer CI/CD model that avoids long-lived AWS credentials in GitHub Secrets.
- A stronger dependency automation story than the minimal Dependabot-style approach.
- A durable event buffer that matches common data platform and platform engineering patterns.

## Decision

Step 1 will use:

- EKS as the managed Kubernetes target.
- Terraform as the infrastructure as code tool for AWS, EKS, IAM, ECR, OIDC, and supporting resources.
- GitOps with Argo CD so cluster state is reconciled from Git.
- Kafka as the durable event buffer between ingest services and downstream writers.
- ECR as the image registry.
- GitHub OIDC for short-lived AWS credentials in CI.
- Federated human access through AWS IAM Identity Center or an enterprise IdP for AWS console/CLI login.
- Renovate for configurable dependency and image update automation.
- CI security gates such as Trivy, kubeconform, kube-linter, Kyverno checks, and Terraform plan review.

MySQL remains the business data store in Step 1 unless a later story explicitly changes the data layer. Kafka replaces the MVP's MySQL queue role, not the business tables.

Git is the source of truth for desired platform and application state. Argo CD makes that explicit by continuously reconciling the cluster toward the Git state rather than relying on manual `kubectl apply`.

GitHub OIDC and AWS STS replace the earlier pattern of storing long-lived AWS access keys in GitHub Secrets. CI assumes a tightly scoped IAM role and receives temporary credentials only when a trusted workflow runs. Human access is separate: administrators should use AWS IAM Identity Center, SSO, or an enterprise identity provider for console and CLI access.

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

5. Keep Dependabot as the main dependency automation tool.

   Pros:

   - Simple and familiar inside GitHub.
   - Good enough for basic dependency alerts and updates.

   Cons:

   - Less flexible for grouped updates, image update strategy, scheduling, and multi-ecosystem platform maintenance.
   - Renovate is a better fit for a platform upgrade story that includes application dependencies, Docker images, Helm charts, and infrastructure modules.

## Consequences

Positive consequences:

- EKS gives the platform a realistic cloud target.
- Terraform makes infrastructure reviewable and repeatable.
- Argo CD removes manual apply as the normal deployment path.
- Kafka gives CPEmon a clearer event-driven architecture.
- GitHub OIDC and federated human access reduce long-lived cloud credential risk.
- ECR gives the image publishing flow a cloud-native registry target.
- Renovate and CI security gates strengthen the DevSecOps story.

Trade-offs:

- More components must be operated and documented.
- Kafka introduces topic, partition, retention, and consumer lag decisions.
- CI and GitOps conventions must be kept simple enough for a small project.
- EKS is more complex than what the demo strictly needs, but that complexity is intentional because the learning goal is cloud platform migration.
