# cpemon-writer Kafka Consumer Group Runbook

## Purpose

Use this runbook to understand, verify, and troubleshoot the
`cpemon-writer` Kafka consumer group.

Covered task:

- `CCPU-91`: Add consumer group configuration.

## Configuration Contract

Default group id:

```text
cpemon-writer
```

Environment variable:

```text
KAFKA_CONSUMER_GROUP_ID=cpemon-writer
```

Helm value:

```yaml
appConfig:
  kafkaConsumerGroupId: cpemon-writer
```

This id should be stable across restarts. Changing it creates a different
Kafka consumer group with a different offset history.

## Mental Model

```text
topic partitions
  -> assigned to cpemon-writer group members
  -> each partition has one active consumer in the group
  -> committed offsets record group progress
```

If `cpemon-writer` has one replica, that pod owns all assigned partitions.

If `cpemon-writer` has multiple replicas, Kafka splits partitions across the
replicas in the same group. More replicas than partitions will leave some pods
idle for that topic.

## Check Rendered Configuration

Helm render:

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml |
  Select-String -Pattern "KAFKA_CONSUMER_GROUP_ID|cpemon-writer"
```

Raw Kubernetes YAML:

```powershell
Select-String -Path k8s/app/cpemon-app-config.yaml,k8s/app/cpemon-writer.yaml -Pattern "KAFKA_CONSUMER_GROUP_ID|cpemon-writer"
```

Repository validation:

```powershell
make cpemon-writer-kafka-consumer-group-check
```

## Live Consumer Group Inspection

Check the writer deployment:

```powershell
kubectl get deploy,pods -n cpemon -l app=cpemon-writer
kubectl describe deploy -n cpemon cpemon-writer
```

Inspect the consumer group:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-consumer-groups.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --describe `
  --group cpemon-writer
```

Important columns:

| Column | Meaning |
| --- | --- |
| `GROUP` | Consumer group id, expected `cpemon-writer`. |
| `TOPIC` | Topic assigned to the group. |
| `PARTITION` | Topic partition. |
| `CURRENT-OFFSET` | Last committed offset for this group. |
| `LOG-END-OFFSET` | Latest offset available in the broker. |
| `LAG` | Messages not yet processed/committed by the group. |
| `CONSUMER-ID` | Current group member. |
| `HOST` | Pod or host identity behind the group member. |

## Troubleshooting

If the group does not exist:

- confirm `KAFKA_CONSUMER_ENABLED=true`
- confirm `cpemon-writer` is running
- confirm the writer can reach the Kafka bootstrap service
- confirm the group id in the pod env is `cpemon-writer`

Check pod env:

```powershell
kubectl exec -n cpemon deploy/cpemon-writer -- printenv |
  Select-String -Pattern "KAFKA_CONSUMER"
```

If lag grows:

- check writer logs for consume, decode, DB, retry, or commit errors
- confirm MySQL is reachable
- compare replica count with topic partition count
- check for rebalance loops
- inspect whether poison messages are blocking progress

If offsets reset unexpectedly:

- check whether `KAFKA_CONSUMER_GROUP_ID` changed
- check whether a new namespace or release rendered a different ConfigMap
- check broker offset retention
- check whether the consumer is using the intended group id

## Interview Summary

A consumer group lets `cpemon-writer` scale horizontally while preserving offset
ownership. Each partition is assigned to one group member at a time. The group
id is the identity Kafka uses to track committed offsets, so it must be stable.
Changing the group id is not a harmless rename; it creates a new offset history.
