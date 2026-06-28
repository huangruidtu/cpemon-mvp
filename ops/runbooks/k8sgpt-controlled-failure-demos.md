# K8sGPT Controlled Failure Demos

## Purpose

Create repeatable Kubernetes failures so developers can practice the K8sGPT
diagnostic workflow without depending on a real incident.

## Demo Files

```text
ops/demos/k8sgpt/bad-image.yaml
ops/demos/k8sgpt/missing-secret.yaml
ops/demos/k8sgpt/broken-service-selector.yaml
ops/demos/k8sgpt/failing-probe.yaml
```

## Apply

```powershell
kubectl apply -f ops/demos/k8sgpt/bad-image.yaml
kubectl apply -f ops/demos/k8sgpt/missing-secret.yaml
kubectl apply -f ops/demos/k8sgpt/broken-service-selector.yaml
kubectl apply -f ops/demos/k8sgpt/failing-probe.yaml
```

## Analyze

```powershell
k8sgpt analyze --namespace cpemon
k8sgpt analyze --namespace cpemon --explain
```

## Verify

```powershell
kubectl get pods,svc,endpoints -n cpemon -l cpemon.io/demo=k8sgpt
kubectl get events -n cpemon --sort-by=.lastTimestamp
```

## Cleanup

```powershell
kubectl delete -f ops/demos/k8sgpt/ --ignore-not-found
```
