# K8sGPT CLI Diagnostics Runbook

## Purpose

Use K8sGPT locally to explain early Kubernetes issues in the CPEmon namespaces.

## Preconditions

* `kubectl` can reach the target cluster.
* `k8sgpt` CLI is installed locally.
* Optional: an AI backend is configured for `--explain`.

## Fast Path

```powershell
kubectl get pods -n cpemon
kubectl get events -n cpemon --sort-by=.lastTimestamp
k8sgpt analyze --namespace cpemon
k8sgpt analyze --namespace cpemon --explain
```

## Verification Loop

For each K8sGPT finding:

```powershell
kubectl describe pod -n cpemon <pod-name>
kubectl logs -n cpemon <pod-name> --tail=100
kubectl get deploy,rs,svc,endpoints -n cpemon
```

K8sGPT output is a starting hypothesis. The confirmed finding must come from
Kubernetes events, object status, logs, metrics, or GitOps state.

## Common Findings

| Symptom | Likely evidence | Verification |
| --- | --- | --- |
| ImagePullBackOff | bad image name or tag | `kubectl describe pod` events |
| CreateContainerConfigError | missing Secret or ConfigMap | env or volume references |
| Service has no endpoints | selector mismatch | compare Service selector and Pod labels |
| Readiness failed | bad probe path or app unhealthy | pod events and application logs |

## Interview Note

The best answer is not "K8sGPT found the bug." The best answer is "K8sGPT gave
us a hypothesis, and we verified it with Kubernetes evidence."
