# Kafka Topics Runbook

## Purpose

Use this runbook to define and validate the initial CPEmon Kafka topics.

Covered task:

- `CCPU-72`: Create initial CPEmon Kafka topics.

## Initial Topics

The Step 1 topics are:

| Topic | Purpose |
| --- | --- |
| `cpemon.device.heartbeat.v1` | Device heartbeat events from CPE/ACS ingestion. |
| `cpemon.wan.status.v1` | WAN status events for connectivity and dashboard updates. |
| `cpemon.deadletter.v1` | Failed or unprocessable events for debugging and replay decisions. |

## Topic Configuration

For Step 1, each topic uses:

```text
partitions: 1
replicationFactor: 1
retention.ms: 604800000
```

That retention value is seven days.

This is intentionally not a production sizing model. It is a small EKS learning-path configuration for a single-controller Kafka install.

## Where Topics Are Defined

The topics are defined in the Kafka Helm values file:

```text
k8s/addons/kafka/values.yaml
```

The relevant section is:

```yaml
provisioning:
  enabled: true
  topics:
    - name: cpemon.device.heartbeat.v1
      partitions: 1
      replicationFactor: 1
      config:
        retention.ms: "604800000"
```

The Bitnami chart provisions topics during install/upgrade when the provisioning job runs successfully.

## Local Validation

Validate that the repository defines the required topics:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-topics.ps1
```

Makefile shortcut:

```powershell
make kafka-topics-check
```

This validates the Git contract, not live broker state.

## Render Validation

When Helm is available:

```powershell
make kafka-template
```

Then inspect the rendered output:

```powershell
Select-String -Path build/helm/kafka-rendered.yaml -Pattern "cpemon.device.heartbeat.v1"
Select-String -Path build/helm/kafka-rendered.yaml -Pattern "cpemon.wan.status.v1"
Select-String -Path build/helm/kafka-rendered.yaml -Pattern "cpemon.deadletter.v1"
```

## Live Validation

After Kafka is installed and ready:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-topics.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --list
```

Expected topics:

```text
cpemon.device.heartbeat.v1
cpemon.wan.status.v1
cpemon.deadletter.v1
```

Describe one topic:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-topics.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --describe `
  --topic cpemon.device.heartbeat.v1
```

## Dead-Letter Topic Boundary

`cpemon.deadletter.v1` is not a trash can for ignoring failures.

It is an operational boundary for events that cannot be processed safely:

- invalid payload
- schema mismatch
- unexpected routing case
- downstream write failure after retries
- poison message behavior

A later application-integration story should define what metadata is sent to the dead-letter topic, such as source topic, failure reason, original payload, and timestamp.

## Troubleshooting

If topics are missing:

```powershell
helm get values kafka -n kafka
helm get manifest kafka -n kafka
kubectl get jobs -n kafka
kubectl logs -n kafka job/<provisioning-job-name>
```

If the topic describe command fails:

```powershell
kubectl get pods,svc -n kafka
kubectl logs -n kafka statefulset/kafka-controller --tail=120
kubectl exec -n kafka statefulset/kafka-controller -- kafka-broker-api-versions.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092
```

## Interview Summary

I defined the first CPEmon Kafka topics before writing producer code. That makes the event boundary explicit: heartbeat events, WAN status events, and a dead-letter topic. For Step 1, I used one partition and replication factor one because the Kafka deployment is a small learning environment, not a production cluster. The important production-style idea is that topic names, retention, and dead-letter handling are deliberate platform contracts, not accidental strings in application code.
