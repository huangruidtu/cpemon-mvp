# cpemon-api HPA Validation and Load-Test Runbook

This runbook explains how to validate the `cpemon-api` HPA in a dev cluster
without claiming production tuning.

Use it after the CPEmon Helm chart has been rendered or synced through Argo CD
with `workloads.cpemonApi.autoscaling.enabled=true`.

## What This Proves

This runbook proves:

* the HPA object exists
* the HPA targets the correct workload
* metrics-server can provide CPU data
* `cpemon-api` can scale within the configured min/max range

It does not prove final production capacity, SLO tuning, or cost optimization.
Those require real traffic profiles and historical metrics.

## Prerequisites

Check metrics-server:

```powershell
kubectl get deployment metrics-server -n kube-system
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods -n cpemon
```

Check workload and HPA:

```powershell
kubectl get rollout cpemon-api -n cpemon
kubectl get hpa cpemon-api-hpa -n cpemon
kubectl describe hpa cpemon-api-hpa -n cpemon
```

If rollout is disabled in the environment, replace `rollout` with
`deployment`.

## Validate Rendered Contract

Run local validation before using a cluster:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-hpa.ps1
helm template cpemon deploy/helm/cpemon `
  -n cpemon `
  -f deploy/helm/cpemon/values-dev.yaml |
  Select-String "HorizontalPodAutoscaler|scaleTargetRef|averageUtilization"
```

Expected dev contract:

```text
kind: HorizontalPodAutoscaler
scaleTargetRef.name: cpemon-api
scaleTargetRef.kind: Rollout
minReplicas: 2
maxReplicas: 4
averageUtilization: 70
```

## Dev Load Test

Port-forward the API:

```powershell
kubectl port-forward -n cpemon svc/cpemon-api 8080:80
```

Run a simple local loop from another terminal:

```powershell
1..2000 | ForEach-Object {
  try {
    Invoke-WebRequest -UseBasicParsing http://localhost:8080/healthz | Out-Null
  } catch {
    Write-Host $_.Exception.Message
  }
}
```

For a stronger cluster-internal load test, run a temporary curl pod:

```powershell
kubectl run cpemon-api-loadtest `
  -n cpemon `
  --image=curlimages/curl:8.10.1 `
  --restart=Never `
  --command -- sh -c "for i in \$(seq 1 5000); do curl -s http://cpemon-api/healthz >/dev/null; done"
```

Watch HPA and pods:

```powershell
kubectl get hpa cpemon-api-hpa -n cpemon -w
kubectl get pods -n cpemon -l app.kubernetes.io/component=api -w
```

Clean up:

```powershell
kubectl delete pod cpemon-api-loadtest -n cpemon --ignore-not-found
```

## Expected Signals

Healthy HPA output should show:

```text
REFERENCE: Rollout/cpemon-api
TARGETS: current CPU / 70%
MINPODS: 2
MAXPODS: 4
```

Scaling may not happen if the endpoint is too cheap or CPU remains below the
target. That is acceptable for this story. The important validation is that the
HPA can read metrics and targets the correct workload.

## Troubleshooting Decision Tree

If `TARGETS` is `<unknown>`:

1. Confirm metrics-server is healthy.
2. Confirm `kubectl top pods -n cpemon` returns data.
3. Confirm the containers have CPU requests.

If HPA says target not found:

1. Check whether the environment renders `Rollout` or `Deployment`.
2. Confirm `scaleTargetRef.kind` matches the rendered workload.
3. Confirm the workload name is `cpemon-api`.

If pods do not scale:

1. Check current CPU utilization.
2. Check `maxReplicas`.
3. Confirm there is enough node capacity.
4. Treat this as a load profile issue, not necessarily a broken HPA.

## Rollback

Disable autoscaling for the environment:

```yaml
workloads:
  cpemonApi:
    autoscaling:
      enabled: false
```

Then sync Argo CD or apply the Helm release again. The workload remains at the
configured `replicaCount`.

## Interview Notes

The interview version:

```text
I separated HPA implementation from HPA validation. The implementation renders
the autoscaler; the validation runbook proves the object, target, metrics-server
dependency, and a dev-only load path. I would not claim this is production
capacity tuning until we have real traffic and historical metrics.
```
