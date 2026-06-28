# Final Evidence Matrix

| Claim | Evidence | Validation |
| --- | --- | --- |
| EKS foundation is modeled with Terraform | `infra/terraform/` | Terraform fmt/validate in live-capable environment |
| CPEmon is Helm-packaged | `deploy/helm/cpemon/` | `make helm-cpemon-validate` |
| GitOps apps are modeled | `k8s/gitops/dev/applications/` | Argo CD sync in live cluster |
| Kafka platform is introduced | `k8s/addons/kafka/`, Kafka docs | `make kafka-architecture-docs-check` |
| Ingest publishes events | `app/acs-ingest/`, `app/pkg/events/` | Go tests and ingest validation scripts |
| Writer consumes events | `app/cpemon-writer/` | writer consumer validation scripts |
| Secrets are externalized | ESO templates and runbooks | render validation, live ESO sync |
| Canary rollout is modeled | Argo Rollouts templates/runbooks | demo scripts and live rollout checks |
| Monitoring exists | `k8s/monitoring/` | ServiceMonitor/dashboard checks |
| Governance exists | `k8s/policies/kyverno/` | Kyverno fixture checks |
| Cost visibility exists | `k8s/addons/opencost/` | OpenCost runbook checks |
| Crossplane self-service exists | `k8s/crossplane/` | Crossplane validation scripts |
| K8sGPT detective layer exists | `k8s/k8sgpt/` | `make k8sgpt-detective-layer-check` |
| Final demo package exists | `docs/final-demo.md` | `make final-portfolio-check` |

## Status Legend

* Implemented: artifact exists in repo.
* Offline validated: script or render check passes without cluster.
* Live validated: command run against a real cluster or AWS account.
* Deferred: intentionally documented future work.

## Honest Boundary

The final portfolio should say:

```text
This repository implements and validates the platform framework offline.
Runtime claims such as Argo CD sync, Crossplane AWS provisioning, K8sGPT live
analysis, and Kafka broker behavior require a live cluster and credentials.
```
