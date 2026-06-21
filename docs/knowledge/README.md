# CPEmon Knowledge Base

This folder captures reusable learning notes from the CPEmon Cloud Platform Upgrade.

The goal is not to archive raw conversations. Each note should extract the durable engineering ideas, connect them to this project, and keep commands or mental models that are useful in future projects.

## Notes

- [Cloud Platform Architecture Migration](cloud-platform-architecture-migration.md)
- [Terraform Remote State and Workflow](terraform-remote-state-workflow.md)
- [ECR, GitHub OIDC, Terraform, and GitHub Actions](ecr-github-oidc-terraform-actions.md)
- [Learning Contract](learning-contract.md)
- [EKS Provisioning with Terraform - VPC Module](eks-provisioning-vpc-module.md)
- [EKS Provisioning with Terraform - Public and Private Subnets](eks-provisioning-subnets.md)
- [EKS Provisioning with Terraform - Cluster Module](eks-provisioning-cluster-module.md)
- [EKS Provisioning with Terraform - Managed Node Group](eks-provisioning-managed-node-group.md)
- [EKS Provisioning with Terraform - Cluster Access](eks-provisioning-cluster-access.md)
- [EKS Provisioning - kubeconfig and kubectl Access](eks-provisioning-kubeconfig-kubectl.md)
- [EKS Provisioning Foundation Review](eks-provisioning-foundation-review.md)
- [EKS Platform Add-ons](eks-platform-addons.md)
- [Helm CPEmon Application](helm-cpemon-application.md)
- [Database and Secret Configuration](database-secret-configuration.md)
- [Kafka Platform Architecture and Migration](kafka-platform-architecture-migration.md)
- [Kafka Platform Introduction](kafka-platform-introduction.md)
- [Kafka Topic Naming Convention](kafka-topic-naming-convention.md)
- [acs-ingest Kafka Producer Refactor](acs-ingest-kafka-producer-refactor.md)
- [cpemon-writer Kafka Consumer Refactor](cpemon-writer-kafka-consumer-refactor.md)

## Architecture Decisions

- [ESO with AWS Secrets Manager and KMS](../../ADR/cloud-platform-upgrade-eso-aws-secrets-manager-kms.md)
- [acs-ingest Kafka Producer Migration Decision](../../ADR/acs-ingest-kafka-producer-migration.md)
- [Kafka Platform Architecture and Migration Boundary](../../ADR/cloud-platform-upgrade-kafka-platform-architecture.md)
- [Kafka Deployment Option for Step 1](../../ADR/cloud-platform-upgrade-kafka-deployment-step1.md)
- [cpemon-writer Kafka Consumer Migration](../../ADR/cpemon-writer-kafka-consumer-migration.md)

## Runbooks

- [CPEmon Helm Application Runbook](../../ops/runbooks/helm-cpemon-application.md)
- [CPEmon API DB Connection Verification](../../ops/runbooks/cpemon-api-db-connection.md)
- [CPEmon Writer DB Write-Path Verification](../../ops/runbooks/cpemon-writer-db-write-path.md)
- [CPEmon ESO Render Validation](../../ops/runbooks/cpemon-eso-render-validation.md)
- [CPEmon Secret Management Runbook](../../ops/runbooks/cpemon-secret-management.md)
- [Kafka Bootstrap Configuration Runbook](../../ops/runbooks/kafka-bootstrap-config.md)
- [acs-ingest Kafka Producer Integration Validation Runbook](../../ops/runbooks/acs-ingest-kafka-producer-validation.md)
- [acs-ingest Kafka Producer Operations Runbook](../../ops/runbooks/acs-ingest-kafka-producer-operations.md)
- [cpemon-writer Kafka Consumer Operations Runbook](../../ops/runbooks/cpemon-writer-kafka-consumer-operations.md)
- [cpemon-writer Kafka Consumer Group Runbook](../../ops/runbooks/cpemon-writer-kafka-consumer-group.md)
- [cpemon-writer Kafka Consumer Lag Runbook](../../ops/runbooks/cpemon-writer-kafka-consumer-lag.md)
- [cpemon-writer Kafka-to-DB Integration Validation](../../ops/runbooks/cpemon-writer-kafka-to-db-validation.md)
- [cpemon-api Kafka-Updated Status Validation](../../ops/runbooks/cpemon-api-kafka-updated-status-validation.md)
- [Kafka Namespace Runbook](../../ops/runbooks/kafka-namespace.md)
- [Kafka Platform Helm Runbook](../../ops/runbooks/kafka-platform-helm.md)
- [Kafka Produce and Consume Validation Runbook](../../ops/runbooks/kafka-produce-consume-validation.md)
- [Kafka Topics Runbook](../../ops/runbooks/kafka-topics.md)
- [Kafka Validation and Observability Runbook](../../ops/runbooks/kafka-validation-observability.md)

## Interview Prep

- [Interview Q&A](interview/README.md)
