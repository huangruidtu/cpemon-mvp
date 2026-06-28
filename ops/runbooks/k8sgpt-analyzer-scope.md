# K8sGPT Analyzer Scope for CPEmon

## First Scope

K8sGPT analysis starts with the `cpemon` namespace and selected platform
objects.

Workload signals:

* Pods
* Deployments
* ReplicaSets
* StatefulSets
* Events
* Services and Endpoints
* ConfigMaps where safe
* Rollouts and AnalysisRuns

## Excluded by Default

* Secret values
* Production-wide cluster scans
* Automatic remediation
* Costly continuous backend analysis

## Diagnostic Command

```powershell
k8sgpt analyze --namespace cpemon
k8sgpt analyze --namespace cpemon --explain
```

## Expansion Path

After the first workflow is trusted, add targeted analysis for:

* `kafka` for broker and topic platform symptoms
* `monitoring` for missing ServiceMonitor or scrape failures
* `crossplane-system` for provider and claim conditions
* `argo-rollouts` for controller-level progressive delivery issues
