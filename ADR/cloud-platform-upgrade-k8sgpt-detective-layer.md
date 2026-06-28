# ADR: K8sGPT Detective Layer for Early Kubernetes Issue Detection

## Status

Accepted for CPEmon Cloud Platform Upgrade story 22.

## Context

CPEmon already has several platform signals:

* Prometheus metrics and alerts
* Grafana dashboards
* Argo CD sync and health status
* Argo Rollouts canary analysis
* Kyverno policy feedback
* OpenCost cost visibility
* Crossplane provisioning status

Those tools are strong at producing evidence. They do not always explain the
likely reason behind a Kubernetes failure in a developer-friendly way.

## Decision

Introduce K8sGPT as a detective layer for CPEmon Kubernetes diagnostics.

K8sGPT is used to analyze Kubernetes objects and explain likely failure causes.
It does not become the source of truth, and it does not automatically remediate
resources. Operators still verify findings with kubectl, Argo CD, Prometheus,
rollout status, events, logs, and runbooks.

The first implementation uses:

* CLI-first diagnostic workflow for local and interview demos.
* GitOps-managed K8sGPT operator installation templates.
* Read-only RBAC for CPEmon and selected platform namespaces.
* Secret template for future AI backend configuration.
* Controlled failure demos for repeatable validation.
* Runbooks, knowledge notes, ADR, and interview Q&A.

## Consequences

Positive:

* Developers get a faster starting point during Kubernetes troubleshooting.
* The platform story now includes a modern AI-assisted operations example.
* The project can explain incidents through evidence plus reasoning.

Tradeoffs:

* K8sGPT explanations must be verified; they can be incomplete or wrong.
* AI backend usage introduces privacy and cost considerations.
* Live validation requires a real cluster, K8sGPT installation, and backend
  credentials that are intentionally not committed to Git.

## Non-Goals

* Automatic remediation.
* Sending raw secrets or unrestricted cluster data to an AI backend.
* Replacing Prometheus, Argo CD, Argo Rollouts, kubectl, or runbooks.
* Proving live EKS backend analysis inside this repository-only task.

## Interview Summary

Say:

```text
I introduced K8sGPT as an AI-assisted detective layer, not as an automated
operator. Prometheus and Argo CD still provide the evidence, while K8sGPT helps
summarize Kubernetes failure causes. I kept the first implementation read-only,
GitOps-managed, namespace-scoped, and backed by runbooks and controlled failure
demos so the operational boundary is clear.
```

Do not say:

```text
K8sGPT automatically fixes production.
K8sGPT replaces observability.
The repo proves live AI analysis against EKS.
```
