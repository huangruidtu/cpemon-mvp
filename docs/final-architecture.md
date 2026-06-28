# Final Architecture

## System Flow

```mermaid
flowchart LR
  CPE["CPE simulator / device"] --> ACS["GenieACS"]
  ACS --> Ingest["acs-ingest"]
  CPE --> API["cpemon-api heartbeat endpoint"]
  Ingest --> Kafka["Kafka topics"]
  Kafka --> Writer["cpemon-writer consumer"]
  Writer --> DB["MySQL read/write model"]
  API --> DB
  API --> User["Operator / dashboard user"]
  Ingest --> Metrics["Prometheus metrics"]
  Writer --> Metrics
  API --> Metrics
  Metrics --> Grafana["Grafana dashboards"]
```

## Platform Control Plane

```mermaid
flowchart TB
  Git["Git repository"] --> Argo["Argo CD"]
  Terraform["Terraform"] --> EKS["EKS foundation"]
  Argo --> Helm["Helm charts"]
  Helm --> Apps["CPEmon workloads"]
  Argo --> Kafka["Kafka addon"]
  Argo --> Monitoring["Prometheus / Grafana"]
  Argo --> ESO["External Secrets Operator"]
  Argo --> Rollouts["Argo Rollouts"]
  Argo --> Kyverno["Kyverno policies"]
  Argo --> OpenCost["OpenCost"]
  Argo --> Crossplane["Crossplane"]
  Argo --> K8sGPT["K8sGPT detective layer"]
  ESO --> Secrets["AWS Secrets Manager / KMS boundary"]
  Crossplane --> AWSResources["Approved app-level AWS resources"]
  Monitoring --> Rollouts
  K8sGPT --> Operators["Human operators"]
```

## Decision Map

| Decision | ADR / docs | Evidence |
| --- | --- | --- |
| Terraform owns EKS foundation | `ADR/cloud-platform-upgrade-crossplane-terraform-boundary.md` | `infra/terraform/` |
| Helm packages CPEmon apps | `docs/knowledge/helm-cpemon-application.md` | `deploy/helm/cpemon/` |
| Argo CD owns GitOps reconciliation | `ADR/cloud-platform-upgrade-argocd-gitops-deployment.md` | `k8s/gitops/dev/applications/` |
| Kafka becomes event buffer | `ADR/cloud-platform-upgrade-kafka-platform-architecture.md` | `k8s/addons/kafka/`, app Kafka packages |
| ESO uses AWS Secrets Manager/KMS | `ADR/cloud-platform-upgrade-eso-aws-secrets-manager-kms.md` | `external-secrets.yaml`, runbooks |
| Argo Rollouts provides canary safety | `ADR/cloud-platform-upgrade-argo-rollouts-canary-deployment.md` | AnalysisTemplates and rollout runbooks |
| Governance starts with Kyverno | `ADR/cloud-platform-upgrade-governance-cost-autoscaling.md` | `k8s/policies/kyverno/` |
| Crossplane adds self-service APIs | `ADR/cloud-platform-upgrade-crossplane-developer-self-service.md` | `k8s/crossplane/` |
| K8sGPT adds detective operations | `ADR/cloud-platform-upgrade-k8sgpt-detective-layer.md` | `k8s/k8sgpt/`, K8sGPT runbooks |

## Architecture Boundary

This repo is a platform engineering case study. It contains implementation
artifacts and offline validation. Some runtime behaviors require a real EKS
cluster, cloud credentials, Argo CD, Kafka brokers, and AI backend credentials.
