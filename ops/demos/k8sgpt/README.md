# K8sGPT Controlled Failure Demos

These demo manifests create safe, isolated Kubernetes failures that K8sGPT
should be able to explain.

Apply only in a disposable dev cluster:

```powershell
kubectl apply -f ops/demos/k8sgpt/bad-image.yaml
kubectl apply -f ops/demos/k8sgpt/missing-secret.yaml
kubectl apply -f ops/demos/k8sgpt/broken-service-selector.yaml
kubectl apply -f ops/demos/k8sgpt/failing-probe.yaml
k8sgpt analyze --namespace cpemon --explain
```

Cleanup:

```powershell
kubectl delete -f ops/demos/k8sgpt/ --ignore-not-found
```
