# Kafka Produce and Consume Validation Runbook

## Purpose

Use this runbook to prove the Step 1 Kafka platform can accept and return a test event.

Covered task:

- `CCPU-74`: Validate manual Kafka produce and consume path.

This validates platform-level Kafka connectivity. It does not validate CPEmon application producer code.

## Prerequisites

Live validation requires:

- `kubectl`
- kubeconfig pointing to the target cluster
- namespace `kafka`
- Helm release `kafka`
- Kafka pod Ready
- bootstrap service reachable inside the cluster
- topics provisioned

Local repository validation can only prove that this runbook exists and includes the expected commands.

## Test Topic

Use:

```text
cpemon.device.heartbeat.v1
```

The test message:

```json
{"source":"manual-kafka-validation","serialNumber":"TEST-CPE-0001","status":"online","ts":"2026-06-21T00:00:00Z"}
```

This shape is intentionally simple. It is not the final application event schema.

## Preflight Checks

Check namespace and Kafka release:

```powershell
kubectl get ns kafka
helm status kafka -n kafka
```

Check Kafka resources:

```powershell
kubectl get pods,svc,statefulset,pvc -n kafka
kubectl rollout status statefulset/kafka-controller -n kafka --timeout=10m
```

Check topics:

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

## Produce a Test Message

Send one test heartbeat event:

```powershell
'{"source":"manual-kafka-validation","serialNumber":"TEST-CPE-0001","status":"online","ts":"2026-06-21T00:00:00Z"}' |
  kubectl exec -i -n kafka statefulset/kafka-controller -- kafka-console-producer.sh `
    --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
    --topic cpemon.device.heartbeat.v1
```

Expected result:

```text
command exits without error
```

Kafka console producer usually does not print a success message for each produced event. The proof comes from consuming the event afterward.

## Consume the Test Message

Read one message from the topic:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- timeout 15 kafka-console-consumer.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --topic cpemon.device.heartbeat.v1 `
  --from-beginning `
  --max-messages 1
```

Expected output includes:

```json
{"source":"manual-kafka-validation","serialNumber":"TEST-CPE-0001","status":"online","ts":"2026-06-21T00:00:00Z"}
```

If older messages already exist, the first message may not be the new one. In that case, either use a temporary validation topic or consume more messages and search for `TEST-CPE-0001`.

## Optional Isolated Validation Topic

If you want an isolated manual test, create a temporary topic:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-topics.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --create `
  --if-not-exists `
  --topic cpemon.validation.manual.v1 `
  --partitions 1 `
  --replication-factor 1
```

Then produce and consume against:

```text
cpemon.validation.manual.v1
```

Delete only if approved:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-topics.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --delete `
  --topic cpemon.validation.manual.v1
```

## Troubleshooting

If producer fails with connection errors:

```powershell
kubectl get svc -n kafka
kubectl describe svc -n kafka kafka
kubectl logs -n kafka statefulset/kafka-controller --tail=120
```

If topic is missing:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-topics.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --list
helm get values kafka -n kafka
kubectl get jobs -n kafka
```

If consumer returns no messages:

- confirm the producer command exited without error
- consume with a higher `--max-messages` value
- use a temporary validation topic
- check broker logs

If `timeout` is unavailable inside the image, run the consumer without `timeout` and stop it manually after the expected message appears.

## Local Runbook Validation

Validate that this runbook contains the expected produce/consume commands:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-produce-consume-runbook.ps1
```

Makefile shortcut:

```powershell
make kafka-produce-consume-runbook-check
```

## Interview Summary

I separated platform connectivity validation from application behavior. A manual produce/consume test proves that Kafka is reachable, topics exist, and the broker can store and return an event. It does not prove that CPEmon application code publishes events correctly. That distinction matters because platform readiness and application integration fail in different ways and should be debugged separately.
