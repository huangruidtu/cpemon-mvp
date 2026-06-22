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
