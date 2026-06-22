# Platform Governance, Cost Visibility, and Basic Autoscaling

Story: `CCPU-144`

This story adds a minimal platform operations layer around CPEmon:

```text
Kyverno governance -> OpenCost visibility -> cpemon-api HPA
```

The goal is not to solve every security, FinOps, or scaling problem in one
step. The goal is to add the first practical controls that make the platform
safer, more transparent, and easier to operate.

## CCPU-199: Architecture Boundary

The story has three lanes:

| Lane | Tool | Responsibility |
| --- | --- | --- |
| Governance | Kyverno | Enforce baseline Kubernetes policy before unsafe workloads are accepted. |
| Cost visibility | OpenCost | Show namespace and workload cost signals so operators can investigate spend. |
| Basic autoscaling | HPA | Let `cpemon-api` scale on a conservative CPU-based signal. |

These lanes are intentionally small. They create a credible platform baseline
without pretending the dev environment has full enterprise security, FinOps, or
autoscaling maturity.

## Ownership Boundary

Platform-owned:

```text
Kyverno installation
Kyverno policies
OpenCost installation
OpenCost access and cost runbooks
metrics-server and Prometheus dependencies
platform validation checklist
```

Application-owned:

```text
cpemon-api resource requests and limits
cpemon-api labels
cpemon-api image tags
cpemon-api HPA values
workload-specific scaling expectations
```

Shared boundary:

```text
The platform provides guardrails.
The application must satisfy them.
```

## Why Kyverno

Kyverno is policy as code for Kubernetes. It can validate resources during
admission and report policy violations through policy reports.

For CPEmon, the first useful policies are:

* require CPU and memory requests and limits
* disallow `latest` image tags
* require standard app labels
* require non-root containers where compatible

This is not the whole security program. It is a baseline that prevents common
operational mistakes from becoming cluster state.

## CCPU-200: Kyverno Platform Installation

Kyverno is installed through the `kyverno-dev` Argo CD Application:

```text
Application:    k8s/gitops/dev/applications/kyverno-dev.yaml
Chart repo:     https://kyverno.github.io/kyverno/
Chart:          kyverno
Chart version:  3.8.1
App version:    v1.18.1
Values file:    k8s/addons/kyverno/values.yaml
Namespace:      kyverno
```

The important design choice is that Kyverno is platform-owned. CPEmon
application charts should not install policy controllers. They should render
workloads that satisfy the policy layer.

The installation and policy package are also separated. CCPU-200 installs the
controllers and CRDs. Later subtasks add the actual `ClusterPolicy` resources
and validation fixtures. This keeps the control plane review separate from the
policy behavior review.

The AppProject allows only the Kyverno chart repository and the `kyverno`
destination namespace needed by this Application. It also keeps manual sync,
prune disabled, and self-heal disabled so CRDs and admission webhooks are
reviewed before reconciliation changes the cluster.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-kyverno-installation.ps1
helm template kyverno kyverno/kyverno `
  --version 3.8.1 `
  --namespace kyverno `
  --values k8s/addons/kyverno/values.yaml
```

## CCPU-201: Baseline Resource Policy

The first Kyverno policy is:

```text
k8s/policies/kyverno/baseline/require-container-resources.yaml
```

It creates:

```text
ClusterPolicy/cpemon-require-container-resources
```

The policy requires every container in Pods created in the `cpemon` namespace
to define:

```text
resources.requests.cpu
resources.requests.memory
resources.limits.cpu
resources.limits.memory
```

The policy is set to `Enforce`, not only audit, because missing requests and
limits break the platform contract:

* Kubernetes scheduling cannot reserve expected capacity.
* HPA CPU utilization math depends on CPU requests.
* OpenCost allocation is less useful when resource intent is missing.
* memory limits reduce the blast radius of a runaway process.

The policy package is deployed by:

```text
k8s/gitops/dev/applications/kyverno-policies-dev.yaml
```

This separate Application lets the platform sync order stay explicit:

```text
kyverno-dev -> kyverno-policies-dev -> cpemon-dev
```

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-resource-policy.ps1
```

## CCPU-202: Image Tag Policy

The second Kyverno policy is:

```text
k8s/policies/kyverno/baseline/disallow-latest-image-tag.yaml
```

It creates:

```text
ClusterPolicy/cpemon-disallow-latest-image-tag
```

The policy rejects Pods in the `cpemon` namespace when a container image ends
with:

```text
:latest
```

This is a release safety rule. In GitOps, a Git commit should describe a
repeatable desired state. A mutable image tag breaks that guarantee because the
registry can move the tag after the Git commit has been reviewed.

Why it matters:

* rollback should point to a known image
* canary analysis should test a known image
* incident review should identify exactly what ran
* audit trails should not depend on registry tag history

The Step 1 policy bans `latest`. A stricter future production policy could
require digests or signed images. That is intentionally deferred so the first
policy remains teachable and low-friction.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-image-tag-policy.ps1
```

## CCPU-203: Labels and Non-Root Policies

CCPU-203 adds two more Kyverno baseline policies:

```text
ClusterPolicy/cpemon-require-standard-labels
ClusterPolicy/cpemon-require-non-root-containers
```

The label policy requires CPEmon Pods to carry the operational labels used by
Helm, Argo CD, Prometheus, kubectl selectors, and cost investigation:

```text
app.kubernetes.io/name
app.kubernetes.io/instance
app.kubernetes.io/managed-by
app.kubernetes.io/part-of
app.kubernetes.io/component
```

The non-root policy requires each CPEmon container to declare:

```text
securityContext.runAsNonRoot: true
securityContext.allowPrivilegeEscalation: false
```

The Helm chart was updated at the same time so CPEmon workloads satisfy the
policy by default:

```text
deploy/helm/cpemon/templates/workloads.yaml
deploy/helm/cpemon/values.yaml
deploy/helm/cpemon/values.schema.json
```

This matters for interviews because the task is not only "write a policy." The
better engineering story is: add a guardrail, make the application comply, and
document how to validate or roll back the guardrail.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-labels-nonroot-policies.ps1
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

## CCPU-204: Policy Validation Fixtures

CCPU-204 adds valid and invalid policy fixtures under:

```text
k8s/policies/kyverno/fixtures
```

The valid fixture has:

* explicit image tag
* required labels
* CPU and memory requests and limits
* non-root security context

The invalid fixtures intentionally violate one policy each:

```text
missing-resources.yaml
latest-image.yaml
missing-labels.yaml
root-container.yaml
```

The live validation story is:

```powershell
kubectl get cpol
kubectl get policyreport -A
kubectl apply -f k8s/policies/kyverno/fixtures/valid/cpemon-valid-pod.yaml
kubectl apply -f k8s/policies/kyverno/fixtures/invalid/latest-image.yaml
```

The valid fixture should be accepted. Invalid fixtures should be rejected by
the Kyverno admission webhook. Policy reports then show the policy evaluation
history in the cluster.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-policy-fixtures.ps1
```

## CCPU-205: OpenCost Platform Installation

OpenCost is installed through the `opencost-dev` Argo CD Application:

```text
Application:    k8s/gitops/dev/applications/opencost-dev.yaml
Chart repo:     https://opencost.github.io/opencost-helm-chart
Chart:          opencost
Chart version:  2.5.23
App version:    1.120.3
Values file:    k8s/addons/opencost/values.yaml
Namespace:      opencost
```

The Step 1 goal is cost visibility, not chargeback. OpenCost gives operators a
place to inspect namespace and workload cost signals before the platform tries
to allocate spend to teams, enforce budgets, or optimize workloads.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-opencost-installation.ps1
helm template opencost opencost/opencost `
  --version 2.5.23 `
  --namespace opencost `
  --values k8s/addons/opencost/values.yaml
```

## CCPU-206: OpenCost Prometheus Integration

OpenCost is configured to query the existing kube-prometheus-stack Prometheus
service:

```text
http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
```

The source of truth is:

```text
k8s/addons/opencost/values.yaml
```

Relevant values:

```yaml
opencost:
  prometheus:
    internal:
      enabled: true
      serviceName: kps-kube-prometheus-stack-prometheus
      namespaceName: monitoring
      port: 9090
    external:
      enabled: false
```

The design choice is to reuse the platform Prometheus instead of creating a
second metrics store. Prometheus owns time-series usage data. OpenCost turns
that data into namespace and workload cost visibility.

Sync order matters:

```text
monitoring-dev -> opencost-dev
```

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-prometheus-integration.ps1
helm template opencost opencost/opencost `
  --version 2.5.23 `
  --namespace opencost `
  --values k8s/addons/opencost/values.yaml
```

Live validation:

```powershell
kubectl get svc -n monitoring kps-kube-prometheus-stack-prometheus
kubectl get pods,svc,deploy -n opencost
kubectl port-forward -n opencost svc/opencost 9003:9003
Invoke-RestMethod "http://localhost:9003/allocation/compute?window=1h&aggregate=namespace"
```

## CCPU-207: Namespace-Level Cost Visibility

The first useful OpenCost view is namespace-level allocation:

```powershell
Invoke-RestMethod "http://localhost:9003/allocation/compute?window=1h&aggregate=namespace"
```

The namespaces to inspect first are:

```text
cpemon
kafka
monitoring
argocd
kyverno
opencost
```

This matches the platform ownership model:

* `cpemon` is the application layer.
* `kafka` is the streaming platform.
* `monitoring` is observability.
* `argocd` is deployment control plane.
* `kyverno` is governance.
* `opencost` is cost visibility overhead.

The goal is to see where cost comes from before discussing optimization,
budgeting, or chargeback. That distinction matters: visibility is a technical
capability; chargeback is an organizational and financial process.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-namespace-cost-visibility.ps1
```

## CCPU-208: OpenCost Access and Cost Investigation

CCPU-208 turns cost visibility into an operator workflow:

```text
OpenCost access -> namespace allocation -> workload drilldown -> Kubernetes resource review -> Git/Argo CD correlation
```

The runbook focuses on a concrete incident drill:

```text
Kafka namespace cost increased unexpectedly in the last 24h.
```

The investigation path is:

```powershell
kubectl port-forward -n opencost svc/opencost 9003:9003
Invoke-RestMethod "http://localhost:9003/allocation/compute?window=24h&aggregate=namespace"
Invoke-RestMethod "http://localhost:9003/allocation/compute?window=24h&aggregate=controller&filter=namespace:kafka"
kubectl get pods,svc,statefulset,pvc -n kafka
argocd app history kafka-dev
git log --oneline -- k8s/addons/kafka k8s/gitops/dev/applications/kafka-dev.yaml
```

This connects cost data to operational facts:

* replica count
* resource requests
* PVC size
* failed pods
* chart value changes
* Argo CD sync history

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-cost-investigation.ps1
```

## CCPU-209: cpemon-api HPA Template and Values

This task adds the first autoscaling implementation for the platform:
`cpemon-api` can now render a Kubernetes `HorizontalPodAutoscaler` from the
Helm chart.

The values contract is:

```yaml
workloads:
  cpemonApi:
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 4
      targetCPUUtilizationPercentage: 70
```

The base chart keeps HPA disabled so production environments opt in
intentionally. The dev values enable it so the rendered manifest is visible
during local validation and GitOps review.

The HPA target follows the workload type:

```text
rollout.enabled=false -> Deployment/apps/v1
rollout.enabled=true  -> Rollout/argoproj.io/v1alpha1
```

That design is important because the Argo Rollouts controller owns the replica
set when canary deployment is enabled. Scaling the Deployment in that mode would
be the wrong control plane target.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-hpa.ps1
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

## CCPU-210: HPA Validation and Dev Load Test

This task separates HPA implementation from live validation. The implementation
proves the chart can render an HPA. The validation runbook explains how to test
that object in a dev cluster.

The runbook checks three layers:

```text
metrics layer:  metrics-server and kubectl top
target layer:   HPA scaleTargetRef points to cpemon-api
behavior layer: dev load can raise CPU enough to observe HPA decisions
```

This is intentionally not production capacity tuning. A dev load test can prove
that autoscaling is wired correctly, but final production values need real
traffic patterns, latency targets, cost constraints, and historical metrics.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-hpa-validation.ps1
```

## CCPU-211: KEDA Step 2 Decision

This task records the autoscaling boundary:

```text
Step 1: HPA for cpemon-api CPU scaling
Step 2: KEDA for event-driven scaling when Kafka lag or queue depth becomes the
        primary scaling signal
```

The ADR is `ADR/cloud-platform-upgrade-hpa-first-keda-step2.md`. The practical
decision runbook is `ops/runbooks/keda-step2-decision.md`.

The interview reason is simple: HPA is the right first autoscaling mechanism
for CPU-based API scaling. KEDA is powerful, but it introduces a new controller
and belongs with event-source scaling, especially Kafka consumer lag for
`cpemon-writer`.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-keda-step2-decision.ps1
```

## Why OpenCost

OpenCost makes Kubernetes cost visible by namespace, workload, and service.

For this project, cost visibility matters because the platform now has multiple
namespaces:

* `cpemon`
* `kafka`
* `monitoring`
* `argocd`
* `kyverno`
* `opencost`

The Step 1 goal is visibility, not chargeback. Before optimizing cost, the
team needs to see where cost is coming from.

## Why HPA First

HorizontalPodAutoscaler is Kubernetes-native and enough for the first scaling
story.

For `cpemon-api`, the conservative Step 1 target is CPU-based scaling:

```text
more API CPU load -> more cpemon-api replicas
```

This depends on:

* resource requests
* metrics-server
* conservative min/max replica settings

## Why KEDA Is Step 2

KEDA is useful when scaling should follow event sources such as Kafka lag,
queue depth, or external metrics.

It is deferred because Story 13 only needs a basic API scaling path. Future
KEDA candidates include:

```text
cpemon-writer scaling from Kafka consumer lag
acs-ingest scaling from intake queue depth
event-driven scaling from external systems
```

Deferring KEDA keeps Step 1 teachable and avoids installing a second scaling
control plane before the basic HPA contract is proven.

## Validation Model

Offline checks prove rendered manifests and documentation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-platform-governance-boundary.ps1
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
go test ./...
```

Live dev-cluster checks, when a cluster is available:

```powershell
kubectl get pods -n kyverno
kubectl get cpol
kubectl get policyreport -A
kubectl get pods -n opencost
kubectl get hpa -n cpemon
kubectl describe hpa cpemon-api -n cpemon
```

## Interview Summary

The concise interview story:

```text
I added a minimal platform governance layer with Kyverno, cost visibility with
OpenCost, and a basic HPA path for cpemon-api. I kept the scope conservative:
policy-as-code guardrails first, visibility before cost optimization, and
CPU-based HPA before event-driven KEDA.
```
