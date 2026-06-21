# Kafka Validation and Observability Runbook

## Purpose

Use this runbook as the top-level validation and observability guide for the Kafka platform introduction story.

Covered task:

- `CCPU-160`: Capture Kafka validation boundary, runbook, and observability notes.

## Validation Layers

Kafka validation has two layers:

| Layer | What It Proves | Requires Live Cluster |
| --- | --- | --- |
| Repository validation | Files, values, docs, scripts, and config contracts exist. | No |
| Live validation | Namespace, Helm release, pods, services, topics, produce/consume, logs, and metrics work. | Yes |

Do not mix these claims. A passing repository check does not prove a running Kafka broker.

## Repository Validation

Run all Kafka repository-level checks:

```powershell
make kafka-namespace-check
make kafka-helm-workflow-check
make kafka-topics-check
make kafka-topic-naming-check
make kafka-config-check
make kafka-architecture-docs-check
make kafka-produce-consume-runbook-check
make kafka-validation-observability-check
```

These checks validate the Story 8 documentation and configuration contracts.

## Live Validation Sequence

### 1. Namespace

```powershell
kubectl get ns kafka --show-labels
```

Expected:

```text
cpemon.io/layer=data-streaming
```

### 2. Helm Release

```powershell
helm status kafka -n kafka
helm get values kafka -n kafka
helm get manifest kafka -n kafka
```

Expected:

```text
STATUS: deployed
```

### 3. Kubernetes Resources

```powershell
kubectl get pods,svc,statefulset,pvc -n kafka
kubectl rollout status statefulset/kafka-controller -n kafka --timeout=10m
```

Expected:

- Kafka pod is Running and Ready.
- Service exists.
- PVC is Bound if persistence is enabled.

### 4. Topics

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-topics.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --list
```

Expected:

```text
cpemon.device.heartbeat.v1
cpemon.wan.status.v1
cpemon.deadletter.v1
```

### 5. Produce and Consume

Follow:

```text
ops/runbooks/kafka-produce-consume-validation.md
```

Expected:

- producer command exits without error
- consumer returns the test message

### 6. CPEmon Config Boundary

```powershell
kubectl get configmap cpemon-app-config -n cpemon -o yaml
```

Expected keys:

```text
KAFKA_BOOTSTRAP_SERVERS
KAFKA_TOPIC_DEVICE_HEARTBEAT
KAFKA_TOPIC_WAN_STATUS
KAFKA_TOPIC_DEADLETTER
```

## Observability Notes

Story 8 keeps Kafka metrics disabled in the Step 1 values because the first goal is platform introduction.

The future observability path should include:

- broker pod readiness
- broker restarts
- PVC usage
- topic produce/consume throughput
- consumer group lag
- under-replicated partitions in multi-broker mode
- offline partitions
- controller health
- dead-letter topic traffic

## Useful Debug Commands

Broker logs:

```powershell
kubectl logs -n kafka statefulset/kafka-controller --tail=120
```

Describe pod:

```powershell
kubectl describe pod -n kafka -l app.kubernetes.io/instance=kafka
```

Check services:

```powershell
kubectl get svc -n kafka
kubectl describe svc -n kafka kafka
```

Check PVCs:

```powershell
kubectl get pvc -n kafka
kubectl describe pvc -n kafka
```

Check broker API:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-broker-api-versions.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092
```

Check consumer groups later:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-consumer-groups.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --list
```

Describe a future consumer group:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-consumer-groups.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --describe `
  --group <consumer-group>
```

## ServiceMonitor Boundary

Kafka metrics and ServiceMonitor are future hardening items.

When enabled later, the project should document:

- which exporter is enabled
- which port exposes metrics
- which namespace owns the ServiceMonitor
- which Prometheus release selects it
- which alerts matter for Step 1

Do not claim Prometheus Kafka metrics until:

```powershell
kubectl get servicemonitor -A
kubectl get targets or inspect Prometheus UI
```

shows Kafka targets are scraped.

## Failure Triage

| Symptom | First Checks |
| --- | --- |
| Pod Pending | `kubectl describe pod`, node capacity, PVC, StorageClass |
| Pod CrashLoopBackOff | broker logs, values, storage permissions |
| Topic missing | provisioning job logs, Helm values, topic list |
| Producer cannot connect | service DNS, pod readiness, broker logs |
| Consumer returns no messages | topic name, offset, old messages, producer success |
| PVC stuck Pending | StorageClass, EBS CSI, volume binding mode |
| Metrics missing | exporter enabled, ServiceMonitor CRD, Prometheus selector |

## Interview Summary

I split Kafka validation into repository validation and live validation. Repository checks prove that manifests, values, runbooks, topic names, config keys, and architecture docs exist. Live checks prove that the cluster can run Kafka: namespace, Helm release, pods, service, PVC, topics, produce/consume, and logs. For observability, I documented the future metrics boundary instead of claiming Prometheus coverage before exporters and ServiceMonitors are enabled.
