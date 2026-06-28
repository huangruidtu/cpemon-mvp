# K8sGPT Security and RBAC Boundary

## Principle

K8sGPT starts with read-only Kubernetes access and no automatic remediation.

The upstream operator chart is a cluster-level controller and renders its own
controller RBAC. CPEmon's boundary is therefore expressed in three places:

* install it as a separately reviewed platform addon;
* keep CPEmon diagnostic usage read-only and namespace-focused;
* forbid automatic remediation and require human verification.

## Scope

Initial namespaces:

* `cpemon`
* `platform`
* future extension: `kafka`, `monitoring`, `crossplane-system`

Initial permissions:

* get/list/watch pods, services, endpoints, events, configmaps
* get/list/watch deployments, replicasets, statefulsets
* get/list/watch Argo Rollouts and AnalysisRuns

Avoid:

* update, patch, delete, create
* reading Secret values
* cluster-wide write permissions

When reviewing the rendered Helm chart, explicitly inspect the generated
ClusterRole. If the operator chart grants broader controller permissions than
the team accepts, keep the CLI-only workflow and defer the operator.

## Why This Matters

K8sGPT can produce helpful explanations, but the explanations are generated
from observed state. A bad interpretation should not be able to mutate the
cluster.

## Review Checklist

* Is the ServiceAccount read-only?
* Does the rendered operator chart RBAC match the team's risk appetite?
* Are Secrets excluded or limited to metadata-level symptoms?
* Is anonymization enabled before a live backend is used?
* Are findings verified before action?
