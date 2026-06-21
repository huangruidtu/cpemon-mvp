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
