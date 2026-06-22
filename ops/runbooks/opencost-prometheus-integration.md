# OpenCost Prometheus Integration Runbook

This runbook validates the OpenCost to Prometheus connection.

## Integration Contract

```text
OpenCost namespace:       opencost
OpenCost Application:     opencost-dev
Prometheus namespace:     monitoring
Prometheus service:       kps-kube-prometheus-stack-prometheus
Prometheus port:          9090
Prometheus URL:           http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
Values file:              k8s/addons/opencost/values.yaml
```

The OpenCost Helm values configure:

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

## Why Prometheus Is Required

OpenCost needs cluster metrics to calculate cost allocation signals. Prometheus
stores the Kubernetes and workload metrics that OpenCost queries for CPU,
memory, pod, namespace, and workload usage.

For this project, kube-prometheus-stack is already the platform monitoring
source of truth. OpenCost should reuse that existing Prometheus instead of
installing a second metrics stack.

## Sync Order

Use this order:

1. `monitoring-dev`
2. `opencost-dev`

Monitoring must be healthy first because OpenCost depends on the Prometheus API.

## Local Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-prometheus-integration.ps1
helm template opencost opencost/opencost `
  --version 2.5.23 `
  --namespace opencost `
  --values k8s/addons/opencost/values.yaml
```

## Live Validation

Confirm Prometheus exists:

```powershell
kubectl get svc -n monitoring kps-kube-prometheus-stack-prometheus
kubectl get pods -n monitoring
```

Confirm OpenCost is running:

```powershell
kubectl get pods,svc,deploy -n opencost
kubectl logs -n opencost deploy/opencost --tail=100
```

Port-forward Prometheus and OpenCost:

```powershell
kubectl port-forward -n monitoring svc/kps-kube-prometheus-stack-prometheus 9090:9090
kubectl port-forward -n opencost svc/opencost 9003:9003
```

Prometheus health:

```powershell
Invoke-RestMethod http://localhost:9090/-/ready
```

OpenCost allocation API:

```powershell
Invoke-RestMethod "http://localhost:9003/allocation/compute?window=1h&aggregate=namespace"
```

Expected result:

* Prometheus returns ready.
* OpenCost allocation API returns namespace allocation data.
* `opencost` logs do not show Prometheus connection failures.

## Troubleshooting

If OpenCost cannot query Prometheus:

```powershell
kubectl get svc -n monitoring kps-kube-prometheus-stack-prometheus -o yaml
kubectl describe pod -n opencost -l app.kubernetes.io/name=opencost
kubectl logs -n opencost deploy/opencost --tail=200
```

Check:

* service name is still `kps-kube-prometheus-stack-prometheus`
* namespace is still `monitoring`
* Prometheus port is `9090`
* `monitoring-dev` synced successfully before `opencost-dev`

## Interview Framing

The concise answer:

```text
I connected OpenCost to the existing kube-prometheus-stack Prometheus service
instead of creating a second metrics source. Prometheus provides the usage
signals; OpenCost turns those signals into namespace and workload cost views.
The key operational dependency is sync order: monitoring first, OpenCost after.
```
