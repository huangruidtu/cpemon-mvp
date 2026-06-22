# cpemon-api HPA Runbook

This runbook documents the Step 1 autoscaling path for `cpemon-api`.

The platform uses Kubernetes HorizontalPodAutoscaler first because it is native,
small, and easy to explain. KEDA is deferred until the project needs event-based
scaling from Kafka lag or another external signal.

## Rendered Objects

The HPA is rendered by the Helm chart when:

```yaml
workloads:
  cpemonApi:
    autoscaling:
      enabled: true
```

The default chart keeps autoscaling disabled. The dev values enable it so the
rendered manifest can be reviewed and validated.

## Scale Target

`cpemon-api` can render as either a Deployment or an Argo Rollouts Rollout.

The HPA template follows that choice:

```text
rollout.enabled=false -> scaleTargetRef kind Deployment, apiVersion apps/v1
rollout.enabled=true  -> scaleTargetRef kind Rollout, apiVersion argoproj.io/v1alpha1
```

This matters because the HPA must scale the controller that owns the pods. When
canary deployment is enabled, Argo Rollouts owns the replica set, so the HPA
targets the Rollout.

## Conservative Defaults

The dev profile uses:

```yaml
minReplicas: 2
maxReplicas: 4
targetCPUUtilizationPercentage: 70
```

These values are intentionally conservative. They prove the autoscaling contract
without allowing an uncontrolled replica increase in a small dev environment.

## Dependency

CPU-based HPA needs metrics-server and CPU requests.

Check metrics-server:

```powershell
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top pods -n cpemon
```

Check requests in the rendered pods:

```powershell
helm template cpemon deploy/helm/cpemon `
  -n cpemon `
  -f deploy/helm/cpemon/values-dev.yaml |
  Select-String "requests:" -Context 0,4
```

## Local Validation

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-hpa.ps1
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

## Live Validation

After syncing the dev chart:

```powershell
kubectl get hpa cpemon-api-hpa -n cpemon
kubectl describe hpa cpemon-api-hpa -n cpemon
kubectl get rollout cpemon-api -n cpemon
kubectl get pods -n cpemon -l app.kubernetes.io/component=api
```

Expected result:

```text
HPA exists in cpemon
scaleTargetRef points to cpemon-api
minReplicas is 2
maxReplicas is 4
CPU target is 70%
```

## Troubleshooting

If the HPA shows `<unknown>` CPU:

1. Check metrics-server health.
2. Confirm the pods have CPU requests.
3. Confirm `cpemon-api` pods are running.
4. Confirm the HPA target kind matches the rendered workload kind.

If the HPA scales too aggressively:

1. Lower `maxReplicas` for dev.
2. Increase `targetCPUUtilizationPercentage`.
3. Check for a real hot path in the API before treating scaling as the fix.

## Interview Notes

The short answer:

```text
I added a conservative CPU-based HPA for cpemon-api. The Helm template targets
Deployment or Rollout depending on the canary setting, because Argo Rollouts
owns the workload when canary deployment is enabled. I kept the default chart
disabled and enabled the path in dev values for validation.
```
