# CPEmon Cloud Platform Upgrade - Step 1 Architecture

Release / Version: Step 1 - EKS GitOps Kafka Platform Upgrade

Status: Draft frozen for implementation planning

## Story Goal

Freeze the Step 1 architecture and define the migration path from the current Kubernetes YAML-based MVP to an EKS-based GitOps platform.

The purpose of Step 1 is not to add tools for their own sake. The purpose is to evolve CPEmon from a lab-friendly Kubernetes MVP into a cloud platform baseline that can support repeatable deployments, pull request based review, managed Kubernetes operations, progressive delivery, security controls, cost visibility, and an event buffer suitable for a telco-style monitoring workload.

## Architecture Freeze Summary

Step 1 freezes the platform direction, not every production hardening decision. The target is an EKS-based GitOps baseline where infrastructure, application packaging, release flow, runtime secrets, and quality gates are all reviewable through Git and pull requests.

The current MVP remains valuable as the baseline story: it shows the CPE/ACS monitoring pipeline, operational demos, and Kubernetes fundamentals. The upgrade branch adds a cloud platform operating model around that MVP rather than replacing the MVP narrative.

Step 1 is considered frozen when the following decisions are clear:

- `main` remains the current YAML-first MVP baseline.
- `codex/cpemon-cloud-platform-upgrade` carries the upgrade documentation and future implementation work.
- AWS EKS is the target managed Kubernetes platform.
- Terraform defines AWS, EKS, IAM, ECR, OIDC, and supporting foundations.
- Helm packages CPEmon services and selected platform components.
- Argo CD reconciles desired state from Git.
- Kafka becomes the durable event buffer while MySQL remains the business data store.
- Argo Rollouts, Prometheus analysis, External Secrets Operator, Kyverno, Trivy, kubeconform, kube-linter, OpenCost, Renovate, and developer golden path documentation form the Step 1 platform controls.
- Crossplane and k8sGPT are deferred to Step 2.

## Current MVP Architecture

The current repository is organized as a Kubernetes-first MVP:

```text
app/          Go services: cpemon-api, acs-ingest, cpemon-writer
docker/       Dockerfiles for application images
k8s/          Raw Kubernetes YAML for apps, MySQL, ingress, monitoring, logging, cron, PDB, NetPol
vm3/          GenieACS and CPE simulator stack outside the cluster
sql/          MySQL schema for current status, history, and queue tables
scripts/      Smoke, backlog, backup/restore, ACS demo, and lab helpers
ops/          Runbooks
ADR/          MVP architecture decision records
docs/         Supporting demo and architecture documents
.github/      Existing Go CI and ECR image publishing workflows
```

Current runtime flow:

```text
CPE simulator on vm3
  -> GenieACS on vm3
  -> ingress-nginx
  -> acs-ingest
  -> MySQL ingest_events queue
  -> cpemon-writer
  -> MySQL business tables
  -> cpemon-api / admin UI
  -> Prometheus, Grafana, Elasticsearch, Kibana, Velero/MinIO
```

The MVP already demonstrates meaningful platform ideas:

- Go services with health endpoints and Prometheus metrics.
- Kubernetes Deployments, Services, Ingress, PDBs, NetworkPolicies, and CronJobs.
- MySQL as both business store and simple durable queue.
- Prometheus/Grafana dashboards and alerts.
- Elasticsearch/Kibana logging.
- Velero/MinIO backup and restore demo.
- GitHub Actions for Go CI and ECR image publishing with AWS OIDC.
- Existing ADRs explaining why the MVP chose raw YAML, no Kafka, minimal HA, MySQL, and external vm3 services.

## Current Limitations

The MVP is intentionally clear and reviewable, but the deployment model has limits that Step 1 should address:

- Raw YAML deployment is easy to inspect but hard to reuse across environments.
- Manual `kubectl apply` creates drift risk between Git and the cluster.
- There is no GitOps reconciliation loop to continuously enforce desired state.
- The target cluster is a lab Kubernetes cluster, not a managed cloud Kubernetes platform.
- MySQL queue tables are acceptable for the MVP but are not a strong event buffer for replay, partitioning, or consumer scaling.
- Release strategy is limited to direct image publishing and manual deployment updates.
- Secrets and runtime configuration are embedded or manually managed in several manifests.
- Security governance is mostly implicit; there are no admission policies or image scan gates.
- Cost visibility is limited.
- PR quality gates exist for Go build/test but do not yet cover Terraform plans, manifest validation, image scans, or policy checks.
- There is no formal developer golden path for creating or promoting a CPEmon service change.

## Step 1 Target Architecture

Step 1 establishes a cloud platform baseline:

- AWS EKS as the managed Kubernetes target.
- Terraform for AWS, EKS, IAM, ECR, and platform infrastructure.
- ECR for application images.
- GitHub OIDC for keyless CI access to AWS.
- Federated human access to AWS console/CLI through AWS IAM Identity Center or an enterprise IdP.
- Helm charts for reusable app and platform packaging.
- Argo CD for GitOps reconciliation.
- Kafka for durable event buffering between ingest and writer paths.
- Argo Rollouts for progressive delivery.
- Prometheus and Grafana for metrics, dashboards, and rollout analysis.
- External Secrets Operator for syncing cloud-managed secrets into Kubernetes.
- Trivy scanning for container and dependency security checks.
- Kyverno minimal policies for namespace, image, resource, and security guardrails.
- OpenCost for cost visibility.
- Renovate for dependency and image update automation.
- PR quality gates for Go, Docker, Helm, Kubernetes schema checks, policy checks, and Terraform plans.
- pre-commit hooks for local developer checks.
- kubeconform and kube-linter for Kubernetes manifest validation.

## Target Operating Model

Step 1 changes the normal operating model from manual cluster changes to reviewed Git-driven changes:

- Developers open pull requests for application, Helm, Terraform, or documentation changes.
- CI validates code, images, Helm output, Kubernetes manifests, policies, and Terraform plans before merge.
- GitHub OIDC gives CI short-lived AWS access for plan, build, and publish operations.
- Human AWS console/CLI access uses federated identity rather than long-lived static keys.
- ECR stores traceable application images.
- Terraform owns platform infrastructure and keeps cloud changes reviewable.
- Argo CD owns Kubernetes desired state reconciliation.
- Helm provides the packaging boundary between raw MVP manifests and reusable environment-specific deployment.
- Kafka absorbs ingest events so writers can scale, lag, and recover without using MySQL queue tables as the main event buffer.
- Prometheus, Grafana, rollout analysis, logs, and OpenCost provide feedback after deployment.

## Target CPEmon Flow

The application flow stays recognizable, but the platform responsibilities move to managed and GitOps-controlled components:

```text
CPE simulator / GenieACS
  -> EKS ingress
  -> acs-ingest
  -> Kafka topic for ingest events
  -> cpemon-writer
  -> MySQL / managed DB candidate for business state
  -> cpemon-api / admin UI
  -> Prometheus, Grafana, logs, rollout analysis, and cost visibility
```

MySQL remains the business data store in Step 1. Kafka replaces the MVP's MySQL queue role, not the business tables.

## Target Architecture Diagram

The diagram source is also stored in `docs/cloud-platform-upgrade-step1-architecture.mmd`.

```mermaid
flowchart LR
  dev["Developer"]
  pr["GitHub PR"]
  ci["PR quality gates<br/>Go, Docker, Trivy, Helm, kubeconform, kube-linter, Terraform plan"]
  oidc["GitHub OIDC"]
  humanid["Federated human access<br/>IAM Identity Center / enterprise IdP"]
  aws["AWS account"]
  ecr["ECR"]
  eks["EKS"]
  tf["Terraform state and modules"]
  argocd["Argo CD"]
  helm["Helm charts"]
  eso["External Secrets Operator"]
  kyverno["Kyverno minimal policies"]
  kafka["Kafka"]
  rollouts["Argo Rollouts"]
  prom["Prometheus / Grafana"]
  opencost["OpenCost"]
  apps["CPEmon services<br/>cpemon-api, acs-ingest, cpemon-writer"]
  mysql["MySQL / managed DB candidate"]
  cpe["CPE simulator / GenieACS"]

  dev --> pr --> ci
  ci --> oidc --> aws
  dev --> humanid --> aws
  ci --> ecr
  ci --> tf
  tf --> eks
  helm --> argocd
  argocd --> eks
  eks --> apps
  eks --> eso
  eks --> kyverno
  eks --> kafka
  eks --> rollouts
  eks --> prom
  eks --> opencost
  cpe --> apps
  apps --> kafka
  kafka --> apps
  apps --> mysql
  apps --> prom
  rollouts --> prom
```

## Migration Path

Step 1 should migrate the MVP in controlled layers. Each layer should be small enough to review independently and should preserve the current MVP behavior until the new platform capability is ready.

1. Freeze planning artifacts.
   - Keep roadmap, architecture, ADRs, diagram, Jira template, and reusable AI prompt aligned.
   - Confirm Step 1 and Step 2 boundaries before adding implementation work.

2. Build the cloud foundation.
   - Add Terraform structure for AWS, EKS, IAM, ECR, GitHub OIDC, and supporting resources.
   - Keep application behavior unchanged while infrastructure foundations are introduced.

3. Package the Kubernetes surface.
   - Convert raw Kubernetes manifests into Helm charts.
   - Preserve labels, probes, services, metrics ports, PDBs, and NetworkPolicy intent from the MVP.

4. Introduce GitOps reconciliation.
   - Add Argo CD Applications so Git becomes the deployment source of truth.
   - Treat manual `kubectl apply` as a break-glass/debug path rather than the normal release path.

5. Standardize image publishing and promotion.
   - Publish images to ECR with traceable tags.
   - Make the source commit, image tag, and deployed workload easy to connect.

6. Replace the queue role with Kafka.
   - Introduce Kafka as the durable event buffer.
   - Keep MySQL for business state.
   - Define topics, consumer behavior, retry expectations, and lag visibility at a baseline level.

7. Add progressive delivery.
   - Add Argo Rollouts for selected CPEmon services.
   - Use Prometheus analysis to decide whether a rollout should continue or pause.

8. Move secrets out of app manifests.
   - Add External Secrets Operator.
   - Define the pattern for syncing cloud-managed secrets into Kubernetes.

9. Add platform quality gates.
   - Add minimal Kyverno policies, Trivy scanning, kubeconform, kube-linter, pre-commit hooks, and Terraform plan checks.
   - Keep these checks focused enough that they teach the platform story without blocking every small iteration.

10. Add cost visibility and automation.
    - Add OpenCost for initial cost visibility.
    - Add Renovate for dependency and image update automation.

11. Finalize developer workflow.
    - Document the developer golden path.
    - Keep service ownership and operational expectations clear in repo documentation.

## Migration Guardrails

- Do not remove or rewrite the current MVP story while building the upgrade branch.
- Do not merge Step 2 tools into Step 1 just because they are attractive platform features.
- Do not introduce production-grade multi-account, multi-region, full database migration, or full portal scope in this Step 1 freeze.
- Keep each implementation story tied to one platform capability and one validation path.
- Update Jira, roadmap, architecture, ADRs, and README links together when the boundary changes.

## Step 1 In Scope

- AWS EKS platform baseline.
- Terraform modules and environment layout.
- ECR repositories, GitHub OIDC integration, and federated human AWS access.
- Helm packaging for CPEmon services and selected platform components.
- Argo CD GitOps deployment model.
- Kafka development/baseline deployment and CPEmon event flow design.
- Argo Rollouts for at least one CPEmon service.
- Prometheus analysis templates for rollout validation.
- External Secrets Operator integration pattern.
- Trivy scanning in CI.
- Minimal Kyverno policies.
- OpenCost deployment and initial cost dashboard.
- Renovate configuration.
- PR quality gates, Terraform plan on PR, pre-commit hooks, kubeconform, and kube-linter.
- Developer golden path documentation.
- ADRs and roadmap updates.
- Incident drill for current MVP operational risks.

## Step 1 Out of Scope

- Crossplane or platform resource provisioning APIs.
- k8sGPT-assisted operational insight.
- Full self-service developer portal.
- Full multi-account AWS landing zone.
- Full production-grade database migration.
- Full multi-region disaster recovery.

These are intentionally deferred so Step 1 remains a platform upgrade baseline rather than a full internal developer platform.

## Step 2 Placeholder

Step 2 should build on the Step 1 baseline and stay intentionally narrow:

- Crossplane or another control plane API for platform resource provisioning.
- k8sGPT-assisted operational insight.

## Developer Golden Path

A Step 1 developer workflow should look like this:

1. Create a branch from `main`.
2. Run pre-commit checks locally.
3. Update Go code, Helm values, Terraform, or docs.
4. Open a pull request.
5. CI runs Go build/test, Docker build validation, Trivy, Helm lint/template, kubeconform, kube-linter, Kyverno policy checks, and Terraform plan.
6. Reviewers inspect app changes and infrastructure plan output.
7. Merge to `main`.
8. Images are published to ECR with traceable tags.
9. Argo CD reconciles the desired state.
10. Argo Rollouts uses Prometheus analysis to validate selected deployments.
11. Grafana, logs, and cost dashboards provide operational feedback.

## Incident Drill: Current MVP Operational Risks

Drill goal: identify where the current MVP can fail operationally before the Step 1 migration begins.

Failure and risk examples:

- Manual `kubectl apply` causes configuration drift.
- Raw YAML is hard to reuse across dev, staging, and production-like environments.
- No standard release promotion path exists from image build to cluster deployment.
- No progressive delivery gate exists before shifting traffic.
- Secrets and configuration are not cleanly managed.
- MySQL queue tables can accumulate backlog if `cpemon-writer` is down or slow.
- There is no clear replay and partition model for event loss or delayed processing.
- Troubleshooting spans multiple tools manually: kubectl, Grafana, Kibana, MySQL, and scripts.
- Cost impact is not visible during load or scaling demos.

Suggested exercise:

1. Pick one current manifest under `k8s/app` and compare Git desired state with live cluster state.
2. Scale `cpemon-writer` to zero and observe backlog behavior.
3. Review where secrets are defined and how they would rotate.
4. Trace how a new image tag becomes a running Pod.
5. Identify which manual steps Argo CD, Helm, External Secrets, and PR checks would remove.

Expected outcome:

- A short list of migration risks to handle before Step 1 implementation begins.
- Agreement that Step 1 should prioritize GitOps reconciliation, packaging, event buffering, secret management, release validation, and quality gates.

## Validation Checklist

- `docs/cloud-platform-upgrade-step1-architecture.md` exists.
- `docs/cloud-platform-upgrade-step1-architecture.mmd` matches the diagram embedded in this document.
- Step 1 in-scope and out-of-scope items are documented.
- Step 2 placeholder is documented.
- Target operating model and target CPEmon flow are documented.
- Migration path is split into reviewable layers.
- Migration guardrails are documented.
- Target architecture diagram is added.
- ADRs are created under `ADR/`.
- README links to this architecture package.
- `docs/cloud-platform-upgrade-roadmap.md` captures Step 1 and Step 2.
- A reusable Jira Story template exists.
