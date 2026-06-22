# OpenCost Access and Cost Investigation Runbook

This runbook describes how to access OpenCost and investigate an unexpected
platform cost increase.

## Access OpenCost

Check the Application and runtime resources:

```powershell
argocd app get opencost-dev
kubectl get pods,svc,deploy -n opencost
kubectl logs -n opencost deploy/opencost --tail=100
```

Port-forward the OpenCost service:

```powershell
kubectl port-forward -n opencost svc/opencost 9003:9003
```

OpenCost API:

```powershell
Invoke-RestMethod "http://localhost:9003/allocation/compute?window=1h&aggregate=namespace"
```

OpenCost UI, if exposed by the chart service in the environment:

```text
http://localhost:9003
```

## Incident Drill: Kafka Namespace Cost Increase

Scenario:

```text
OpenCost shows the `kafka` namespace cost increased unexpectedly in the last 24h.
```

Step 1: Confirm namespace allocation:

```powershell
Invoke-RestMethod "http://localhost:9003/allocation/compute?window=24h&aggregate=namespace"
```

Step 2: Drill into workloads:

```powershell
Invoke-RestMethod "http://localhost:9003/allocation/compute?window=24h&aggregate=controller&filter=namespace:kafka"
```

Step 3: Inspect Kafka runtime resources:

```powershell
kubectl get pods,svc,statefulset,pvc -n kafka
kubectl describe statefulset -n kafka kafka
kubectl top pods -n kafka
```

Step 4: Check recent deployment or chart changes:

```powershell
argocd app history kafka-dev
argocd app diff kafka-dev
git log --oneline -- k8s/addons/kafka k8s/gitops/dev/applications/kafka-dev.yaml
```

Step 5: Check common cost drivers:

* replica count increased
* CPU or memory requests increased
* PVC size or storage class changed
* failed pods are restarting and consuming resources
* monitoring scrape or exporter configuration changed
* load test or retention behavior increased broker activity

## Cleanup And Resource Review Checklist

For each high-cost namespace:

```powershell
kubectl get deploy,statefulset,daemonset,pod,pvc -n <namespace>
kubectl top pods -n <namespace>
kubectl describe pvc -n <namespace>
```

Review:

* requests and limits
* replica counts
* persistent volume sizes
* failed or pending pods
* recent Argo CD sync history
* whether the cost aligns with the environment purpose

## What To Record

Capture:

* OpenCost query window
* namespace and workload driving the increase
* relevant Argo CD revision
* resource request or replica changes
* whether the change was expected
* follow-up action and owner

## Interview Framing

The concise answer:

```text
I treated OpenCost as an operational investigation tool. If Kafka cost spikes,
I start with namespace allocation, drill into workload/controller allocation,
then correlate that with Kubernetes resources, PVCs, Argo CD history, and
recent Git changes. That turns cost visibility into an actionable platform
runbook.
```
