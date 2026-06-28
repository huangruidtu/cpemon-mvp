# CPEmon Cloud Platform Upgrade

CPEmon is a telco-style CPE monitoring project upgraded into an interview-ready
cloud platform engineering case study.

The original MVP proved an end-to-end device monitoring path. This upgrade
packages that MVP into an EKS-oriented platform with Terraform, Helm, GitOps,
Kafka, External Secrets, Argo Rollouts, Prometheus/Grafana, Kyverno, OpenCost,
Crossplane, and K8sGPT.

The repo is intentionally written as a portfolio project: each major platform
claim links to implementation files, runbooks, ADRs, diagrams, and validation
commands.

## What This Project Shows

```text
device events -> Kafka-backed ingestion -> writer -> API/read model
             -> deployed by Helm and Argo CD
             -> protected by policy, secrets, rollout, and observability layers
             -> explained through runbooks, ADRs, diagrams, and interview notes
```

## Platform Capabilities

| Capability | Evidence |
| --- | --- |
| EKS foundation with Terraform | `infra/terraform/`, `docs/knowledge/eks-*`, `ops/runbooks/eks-*` |
| Application packaging with Helm | `deploy/helm/cpemon/`, `ops/runbooks/helm-cpemon-application.md` |
| GitOps deployment with Argo CD | `k8s/gitops/dev/applications/`, `docs/knowledge/argocd-gitops-deployment.md` |
| Kafka event platform | `k8s/addons/kafka/`, `docs/knowledge/kafka-platform-introduction.md` |
| Producer/consumer refactor | `app/acs-ingest/`, `app/cpemon-writer/`, `docs/knowledge/*kafka*refactor.md` |
| Secrets with ESO and AWS boundary | `deploy/helm/cpemon/templates/external-secrets.yaml`, `ops/runbooks/cpemon-secret-management.md` |
| Progressive delivery | `deploy/helm/cpemon/templates/analysis-templates.yaml`, `ops/runbooks/argo-rollouts-cpemon-api.md` |
| Monitoring and dashboards | `k8s/monitoring/`, `docs/knowledge/monitoring-observability-upgrade.md` |
| Governance and cost visibility | `k8s/policies/kyverno/`, `k8s/addons/opencost/`, `docs/knowledge/platform-governance-cost-autoscaling.md` |
| Crossplane self-service | `k8s/crossplane/`, `docs/knowledge/crossplane-developer-self-service.md` |
| K8sGPT detective layer | `k8s/k8sgpt/`, `docs/knowledge/k8sgpt-detective-layer.md` |
| Final demo and interview package | `docs/golden-path/`, `docs/final-architecture.md`, `docs/final-demo.md` |

## Golden Path

Start here:

1. [Golden Path Index](docs/golden-path/README.md)
2. [Local Development and Offline Validation](docs/golden-path/01-local-development.md)
3. [EKS Foundation and GitOps Platform Path](docs/golden-path/02-eks-gitops-platform.md)
4. [Release Flow with Helm, Kafka, Argo CD, and Argo Rollouts](docs/golden-path/03-release-flow.md)
5. [Developer Self-Service Path](docs/golden-path/04-developer-self-service.md)
6. [Final Operational Runbook and Incident Drill](docs/golden-path/05-operational-runbook.md)
7. [Final Architecture](docs/final-architecture.md)
8. [Final Demo](docs/final-demo.md)
9. [Final Interview Pack](docs/final-interview-pack.md)
10. [Final Evidence Matrix](docs/final-evidence-matrix.md)

## Quick Validation

Run the repo-level checks from the project root:

```powershell
go test ./...
make helm-cpemon-validate
make k8sgpt-detective-layer-check
make final-portfolio-check
```

Some checks require tools to be installed locally. Live Kubernetes checks
require a real kubeconfig and cluster. The repository never claims a live EKS,
Argo CD, Crossplane, or K8sGPT result unless a command can be run against a
real cluster.

## Demo Path

For a 15-minute interview demo:

1. Explain the [final architecture](docs/final-architecture.md).
2. Show the [evidence matrix](docs/final-evidence-matrix.md).
3. Walk through the [golden path](docs/golden-path/README.md).
4. Run local validation commands.
5. Explain the release flow and canary rollback boundary.
6. Walk the incident drill: heartbeat missing from API.
7. Close with the [interview pack](docs/final-interview-pack.md).

## Live Validation Boundary

Implemented and offline-validated:

* repository structure, manifests, Helm chart, docs, runbooks, ADRs, demos;
* Go unit tests and repo validation scripts where tools are available;
* GitOps manifests and Helm rendering paths;
* K8sGPT, Crossplane, Kyverno, OpenCost, and Argo CD templates.

Requires a real environment:

* EKS apply/plan against a real AWS account;
* Argo CD sync and health status;
* Kafka produce/consume against a live broker;
* Prometheus/Grafana runtime dashboards;
* Crossplane provisioning against AWS;
* K8sGPT `analyze` with installed CLI/operator and backend credentials.

## Interview Summary

Use this concise version:

```text
I upgraded a Kubernetes-first monitoring MVP into an EKS-oriented platform
engineering project. I kept Terraform responsible for the foundation, used Helm
and Argo CD for application delivery, introduced Kafka for durable event flow,
added Argo Rollouts and Prometheus analysis for safer releases, used ESO for
secret boundaries, added governance and cost visibility with Kyverno and
OpenCost, exposed developer self-service patterns with Crossplane, and added
K8sGPT as a read-only detective layer. The final repo includes diagrams,
runbooks, ADRs, validation scripts, and an evidence matrix so every claim can
be traced to code or documentation.
```
