# KEDA Step 2 Decision Runbook

This runbook explains when to keep HPA and when to add KEDA.

It is a decision aid, not an installation guide. KEDA is intentionally deferred
from Story 20.

## Step 1 Decision

Use HPA for `cpemon-api`:

```text
signal: CPU utilization
controller: Kubernetes HPA
target: cpemon-api Deployment or Rollout
dependency: metrics-server
```

## Step 2 Decision

Use KEDA when the scaling signal is event-driven:

```text
Kafka lag
queue depth
scheduled windows
external metrics
```

## HPA vs KEDA

| Area | HPA | KEDA |
| --- | --- | --- |
| Best signal | CPU, memory, native metrics | Event source metrics |
| Controller footprint | Built into Kubernetes | Additional controller and CRDs |
| CPEmon Step 1 fit | Good for cpemon-api | Too early |
| Future fit | Limited for Kafka lag | Strong for cpemon-writer |
| Interview framing | Conservative baseline | Event-driven Step 2 |

## Future KEDA Readiness Checklist

Before implementing KEDA, confirm:

* Kafka metrics are available in Prometheus.
* Consumer group lag is visible by group and topic.
* The workload owner knows the target lag threshold.
* The team agrees on min/max replica limits.
* OpenCost can show the cost effect of scaling.
* Rollback is documented for `ScaledObject` changes.

## Candidate ScaledObject Shape

Future example only:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cpemon-writer-kafka-lag
  namespace: cpemon
spec:
  scaleTargetRef:
    name: cpemon-writer
  minReplicaCount: 1
  maxReplicaCount: 4
  triggers:
    - type: kafka
      metadata:
        bootstrapServers: kafka.kafka.svc.cluster.local:9092
        consumerGroup: cpemon-writer
        topic: cpemon.device.heartbeat.v1
        lagThreshold: "100"
```

Do not apply this sample as-is. It needs authentication, topic validation, and
real lag thresholds.

## Interview Notes

The short version:

```text
HPA handles the first CPU-based cpemon-api autoscaling path. KEDA is reserved
for Step 2 because the strongest CPEmon KEDA use case is Kafka-lag scaling for
cpemon-writer, and that needs stable lag metrics and threshold decisions.
```
