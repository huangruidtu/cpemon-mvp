# Story 1 Interview Q&A: Architecture Migration

## 1. How would you describe the CPEmon Cloud Platform Upgrade?

**Answer**

CPEmon started as a YAML-first Kubernetes MVP for a CPE monitoring pipeline. The upgrade changes the operating model rather than replacing the application story. The goal is to move from manual lab-style Kubernetes operations to a managed cloud platform baseline with Terraform, EKS, ECR, GitHub OIDC, Helm, Argo CD, Kafka, security gates, and clearer developer workflows.

The MVP proves the application pipeline. The upgrade proves how that pipeline would be operated, reviewed, deployed, secured, and monitored in a more production-like platform.

**Deep follow-up**

Why not just rebuild everything from scratch on EKS?

**Strong response**

Rebuilding would hide the migration thinking. The useful part is preserving the working MVP behavior while replacing operational boundaries one layer at a time: infrastructure first, image publishing, packaging, GitOps, event buffering, secrets, delivery gates, and observability. That is closer to real platform migration work.

**Project evidence**

- `docs/cloud-platform-upgrade-step1-architecture.md`
- `docs/cloud-platform-upgrade-roadmap.md`
- `ADR/cloud-platform-upgrade-from-yaml-first-mvp.md`

## 2. Why was raw Kubernetes YAML acceptable in the MVP but not enough for the platform upgrade?

**Answer**

Raw YAML was good for the MVP because it made Kubernetes objects explicit and easy to inspect. It helped show Deployments, Services, Ingress, probes, metrics ports, PDBs, NetworkPolicies, and CronJobs directly.

The limitation appears when the project needs repeatable environments, reviewable promotion, drift control, and standardized packaging. Manual `kubectl apply` does not provide a strong source-of-truth model, and raw YAML becomes repetitive across environments. That is why the upgrade introduces Helm for packaging and Argo CD for GitOps reconciliation.

**Deep follow-up**

Is Helm always better than raw YAML?

**Strong response**

No. Helm adds templating complexity. Raw YAML is often better for learning and small fixed deployments. Helm becomes useful when the same application must be deployed with different values, consistent labels, reusable templates, and CI-rendered manifest validation.

## 3. What does GitOps change operationally?

**Answer**

GitOps changes deployment from "what did someone apply?" to "what does Git say the cluster should look like?" With Argo CD, Git becomes the source of truth, pull requests become the review boundary, and the controller continuously reconciles the cluster to the desired state.

Manual cluster changes become drift instead of normal operations.

**Deep follow-up**

Does GitOps remove the need for CI?

**Strong response**

No. CI and GitOps are complementary. CI validates the change before merge: build, test, scan, render manifests, validate Terraform plans. GitOps reconciles the approved desired state after merge.

## 4. Why introduce Kafka if MySQL queue tables already work?

**Answer**

MySQL queue tables are acceptable in the MVP because they are simple and easy to demo. Kafka is introduced for the event-buffer role in the platform upgrade because it gives retention, replay, partitions, consumer scaling, and consumer lag visibility.

Kafka replaces the queue role, not the business database role. MySQL can still remain the system of record for business state.

**Deep follow-up**

What risk does Kafka add?

**Strong response**

Kafka adds operational complexity: topic design, partition count, retention, consumer group behavior, lag monitoring, retry/dead-letter strategy, and cost. That is why it belongs in a specific story rather than being mixed into the initial architecture freeze.

## 5. How did you control scope in the platform upgrade?

**Answer**

The upgrade was split into Step 1 and Step 2. Step 1 focuses on the platform baseline: EKS, Terraform, ECR, OIDC, Helm, Argo CD, Kafka, secrets, security gates, cost visibility, and developer workflow. Step 2 defers platform API and operational insight ideas such as Crossplane and k8sGPT.

The important principle is that a good roadmap says "not yet" as clearly as it says "yes."

**Deep follow-up**

How do you prevent tool-driven architecture?

**Strong response**

Every tool must map to an operating problem: Terraform for infrastructure review, Argo CD for drift/reconciliation, Helm for packaging, Kafka for durable event buffering, External Secrets for secret delivery, and Trivy/Kyverno/kubeconform for quality gates. If a tool does not solve a current story's problem, it is deferred.
