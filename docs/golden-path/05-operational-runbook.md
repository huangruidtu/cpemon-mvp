# Final Operational Runbook and Incident Drill

## Incident

Device heartbeat is not visible from the API.

## Goal

Trace the issue across the full platform instead of guessing at one component.

## Triage Path

1. Check API symptom.

```powershell
kubectl get pods -n cpemon
kubectl logs -n cpemon deploy/cpemon-api --tail=100
```

2. Check ingest service.

```powershell
kubectl logs -n cpemon deploy/acs-ingest --tail=100
kubectl get servicemonitor -n monitoring
```

3. Check Kafka.

```powershell
kubectl get pods -n kafka
kubectl logs -n kafka statefulset/kafka-controller --tail=100
```

4. Check consumer group and writer.

```powershell
kubectl logs -n cpemon deploy/cpemon-writer --tail=100
```

5. Check database path.

```powershell
kubectl get pods -n cpemon -l app.kubernetes.io/name=mysql
```

6. Check Argo CD desired state.

```powershell
argocd app get cpemon-dev
argocd app diff cpemon-dev
```

7. Check rollout status.

```powershell
kubectl argo rollouts get rollout cpemon-api -n cpemon
```

8. Check observability.

```text
Grafana dashboard -> pipeline panel
Prometheus alerts -> API and ingest metrics
OpenCost -> unexpected resource pressure or cost shift
```

9. Use K8sGPT as a detective layer.

```powershell
k8sgpt analyze --namespace cpemon --explain
```

K8sGPT output is a hypothesis. Verify with Kubernetes events, logs, metrics,
and GitOps state.

## Decision Points

* Roll back if a recent rollout correlates with the failure.
* Escalate to platform if Kafka, storage, ingress, or cluster networking is
  involved.
* Escalate to app owner if code-level validation or schema handling fails.

## Evidence To Capture

* affected endpoint;
* failing pod or rollout;
* Kafka topic or consumer evidence;
* database evidence;
* dashboard/alert evidence;
* Argo CD revision;
* human decision.
