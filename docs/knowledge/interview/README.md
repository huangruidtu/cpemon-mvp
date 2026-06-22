# CPEmon Interview Q&A

This folder turns CPEmon Cloud Platform Upgrade work into interview-ready material.

Use these notes to practice explaining:

- What problem the project solved.
- Why a design choice was made.
- What trade-offs were considered.
- How the implementation was validated.
- What follow-up work remains.

The goal is not to memorize answers word for word. The goal is to build a clear mental model and have concrete project evidence ready.

## Question Sets

- [Story 1: Architecture Migration](story-01-architecture-migration.md)
- [Story 2: Terraform Remote State](story-02-terraform-remote-state.md)
- [Story 3: ECR, GitHub OIDC, and Image Publishing](story-03-ecr-github-oidc.md)
- [Story 4: EKS Provisioning - VPC Module](story-04-eks-vpc-module.md)
- [Story 5: EKS Provisioning - Public and Private Subnets](story-05-eks-subnets.md)
- [Story 6: EKS Provisioning - Cluster Module](story-06-eks-cluster-module.md)
- [Story 7: EKS Provisioning - Managed Node Group](story-07-eks-managed-node-group.md)
- [Story 8: EKS Provisioning - Cluster Access](story-08-eks-cluster-access.md)
- [Story 9: EKS Provisioning - kubeconfig and kubectl Access](story-09-eks-kubeconfig-kubectl.md)
- [Story 10: EKS Provisioning Capstone and Incident Drill](story-10-eks-provisioning-capstone.md)
- [Story 11: EKS Platform Add-ons](story-11-eks-platform-addons.md)
- [Story 12: Helm CPEmon Application](story-12-helm-cpemon-application.md)
- [Story 13: Database and Secret Configuration](story-13-database-secret-configuration.md)
- [Story 14: Kafka Platform Introduction](story-14-kafka-platform-introduction.md)
- [Story 15: acs-ingest Kafka Producer Refactor](story-15-acs-ingest-kafka-producer-refactor.md)
- [Story 16: cpemon-writer Kafka Consumer Refactor](story-16-cpemon-writer-kafka-consumer-refactor.md)
- [Story 17: Argo CD GitOps Deployment](story-17-argocd-gitops-deployment.md)
- [Story 18: Monitoring and Observability Upgrade](story-18-monitoring-observability-upgrade.md)
- [Story 19: Argo Rollouts Canary Deployment](story-19-argo-rollouts-canary-deployment.md)
- [Story 20: Platform Governance, Cost Visibility, and Basic Autoscaling](story-20-platform-governance-cost-autoscaling.md)
- [acs-ingest Kafka Producer Learning Notes](acs-ingest-kafka-producer-learning-notes.md)
- [cpemon-writer Kafka Consumer Learning Notes](cpemon-writer-kafka-consumer-learning-notes.md)
- [Kafka Platform Learning Notes](kafka-platform-learning-notes.md)

## Practice Focus

For Story 12, practice three layers:

- the 90-second project story
- the tool boundaries between Terraform, Helm, kubectl, and Argo CD
- render failure troubleshooting with `helm lint` and `helm template`

For Story 13, practice the database and secret migration boundary:

- why Step 1 keeps MySQL in EKS
- why RDS is deferred but still the production direction
- how `DB_DSN` lets the database implementation change behind a stable application contract
- how ESO, AWS Secrets Manager, KMS, and IRSA split responsibilities

For Story 14, practice the Kafka platform introduction boundary:

- why the MVP did not use Kafka
- why the cloud-platform upgrade introduces Kafka now
- why Step 1 starts with Helm chart based Kafka
- why Strimzi and MSK are future hardening options
- how `KAFKA_BOOTSTRAP_SERVERS` and topic names keep future migration flexible
- how to explain the 60-second Kafka migration story from the learning notes

For Story 15, practice the acs-ingest Kafka producer narrative:

- why the database intake path remains durable
- why Kafka publishing is behind `EventPublisher`
- how topic/key/schema choices protect consumers
- why retry creates at-least-once delivery and idempotency requirements
- how logs, metrics, unit tests, and the live validation runbook prove the change

For Story 10 of the Kafka application migration, practice the cpemon-writer
consumer narrative:

- why `EventConsumer` mirrors `EventPublisher` on the consumer side
- why partition and offset metadata belong in the consumed event envelope
- why offsets should be committed only after successful MySQL writes
- how fake consumers keep unit tests broker-free
- how at-least-once delivery changes database write design
- how retry, dead-letter publishing, lag metrics, structured logs, and API
  validation turn the implementation into an operational story

For Story 11 of the deployment migration, practice the Argo CD GitOps
narrative:

- why Argo CD comes after Terraform and Helm
- why GitHub Actions remains CI while Argo CD owns CD
- how `argocd` namespace installation is verified
- why the learning install can use upstream stable manifests
- why production should pin versions and harden SSO/RBAC/TLS
- why manual sync, prune disabled, and self-heal disabled are deliberate guardrails
- how drift detection works and why rollback should be Git-first
- how to debug OutOfSync, Degraded, missing CRDs, bad image tags, wrong paths, and AppProject permission failures

For Story 19, practice the Argo Rollouts canary narrative:

- why `cpemon-api` moved from Deployment to Rollout
- how stable and canary Services support limited exposure
- why 20% and 50% gates are useful interview examples
- how 5xx and p95 AnalysisRuns protect reliability and latency
- how manual promote differs from `promote --full`
- how abort differs from Git-first rollback
- how the healthy and failed demo scripts prove both success and safety paths

For Story 20, practice the platform governance and visibility narrative:

- why Kyverno belongs in the platform layer
- why OpenCost is visibility before chargeback
- why HPA is the right Step 1 autoscaling tool
- why KEDA is deferred to Step 2 for event-driven scaling
- how policy, cost, and autoscaling together make the platform more operationally mature
