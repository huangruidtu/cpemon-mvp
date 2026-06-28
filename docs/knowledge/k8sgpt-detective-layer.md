# K8sGPT Detective Layer

This note captures story 22 of the CPEmon Cloud Platform Upgrade: adding K8sGPT
as a Kubernetes detective layer for early issue detection.

## Mental Model

```text
Prometheus = what changed in metrics
Argo CD = what changed in GitOps state
Argo Rollouts = what changed during progressive delivery
kubectl events/logs = what Kubernetes observed
K8sGPT = likely explanation and next diagnostic questions
human operator = final decision
```

K8sGPT is not the source of truth. It is an assistant that helps turn raw
Kubernetes symptoms into a faster troubleshooting path.

## CCPU-231: Detective Layer Scope

The architecture boundary is:

```text
K8sGPT reads cluster evidence -> summarizes likely causes -> operator verifies
```

It complements:

* Prometheus alerts
* Grafana dashboards
* Argo CD health
* Argo Rollouts status
* Kyverno admission feedback
* OpenCost cost signals
* Crossplane condition status

It does not own remediation, deployment, or policy enforcement.

## CCPU-232: Operating Mode and Backend Strategy

The first mode is CLI plus optional operator.

CLI is useful because a developer can run:

```powershell
k8sgpt analyze --namespace cpemon --explain
```

The operator is useful because a platform team can install the controller
through Argo CD and eventually expose repeatable analysis results.

The backend is configured through a Kubernetes Secret template. Real API keys
must come from a secret manager or local operator input, not Git.

## CCPU-233: CLI Diagnostic Workflow

Local diagnostic loop:

```powershell
kubectl get pods -n cpemon
kubectl get events -n cpemon --sort-by=.lastTimestamp
k8sgpt analyze --namespace cpemon
k8sgpt analyze --namespace cpemon --explain
kubectl describe pod -n cpemon <pod-name>
kubectl logs -n cpemon <pod-name> --tail=100
```

The important skill is comparing K8sGPT output with Kubernetes evidence.

## CCPU-234 and CCPU-240: GitOps Wiring

The repo adds two Applications:

```text
k8sgpt-dev        installs the K8sGPT operator chart
k8sgpt-config-dev applies CPEmon K8sGPT config and RBAC
```

Both use manual sync and disabled prune/self-heal annotations at first. That is
intentional because observability and detective tools should be introduced
carefully before automation is enabled.

## CCPU-235 and CCPU-236: Security and Backend Boundary

The default boundary is read-only and namespace-scoped.

One practical nuance: the upstream operator is a cluster-level controller, so
the rendered Helm chart must be reviewed before live installation. The safe
fallback is CLI-only diagnostics until the team accepts the operator RBAC.

Security rules:

* Do not commit backend API keys.
* Do not send raw secrets to an AI backend.
* Prefer anonymization.
* Keep write permissions out of the initial design.
* Treat generated explanations as hypotheses.

## CCPU-237: Analyzer Scope

The first scope is CPEmon application diagnostics:

* Pods
* Deployments
* ReplicaSets
* Services
* Endpoints
* Events
* ConfigMaps where safe
* Argo Rollouts and AnalysisRuns

Secrets are referenced only by metadata or missing-reference symptoms, not by
secret values.

## CCPU-238 and CCPU-239: Controlled Failure Demos

The repo includes safe demo failures:

* Bad image tag
* Missing Secret reference
* Broken Service selector
* Failing readiness probe

These are intentionally small because they teach the K8sGPT workflow without
requiring a production incident.

## CCPU-241 and CCPU-242: Runbook Usage

Developer troubleshooting uses K8sGPT to shorten time to first hypothesis.
Incident triage uses K8sGPT to summarize symptoms, but the incident commander
still needs evidence from monitoring and Kubernetes commands.

## CCPU-243: Observability Integration Boundary

K8sGPT can enrich alerts in the future, but this story does not wire automatic
Alertmanager, Slack, or Jira comments. That is a later maturity step.

## CCPU-244 and CCPU-246: Validation Boundary

Offline validation checks files, GitOps manifests, docs, and interview notes.
Live validation requires:

* A reachable cluster
* K8sGPT CLI installed
* K8sGPT operator installed
* A backend API key if explanation mode is used
* Controlled demo manifests applied in a disposable namespace

## Interview Summary

Strong answer:

```text
I added K8sGPT as a read-only detective layer. I used GitOps to manage the
operator, scoped RBAC to CPEmon namespaces, kept AI credentials out of Git,
created safe failure demos, and documented that every AI explanation must be
verified against Kubernetes events, logs, Prometheus, and Argo CD state.
```
