# Kafka Bootstrap Configuration Runbook

## Purpose

Use this runbook to validate the CPEmon Kafka bootstrap and topic-name configuration boundary.

Covered task:

- `CCPU-73`: Add Kafka bootstrap server configuration.

## Configuration Contract

The CPEmon application config boundary now includes:

| Key | Step 1 Value | Purpose |
| --- | --- | --- |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka.kafka.svc.cluster.local:9092` | Internal Kafka bootstrap endpoint. |
| `KAFKA_TOPIC_DEVICE_HEARTBEAT` | `cpemon.device.heartbeat.v1` | Topic for device heartbeat events. |
| `KAFKA_TOPIC_WAN_STATUS` | `cpemon.wan.status.v1` | Topic for WAN status events. |
| `KAFKA_TOPIC_DEADLETTER` | `cpemon.deadletter.v1` | Topic for failed or unprocessable events. |

## Where It Lives

Helm values:

```text
deploy/helm/cpemon/values.yaml
```

Helm ConfigMap template:

```text
deploy/helm/cpemon/templates/configmap.yaml
```

Raw manifest bridge:

```text
k8s/app/cpemon-app-config.yaml
```

Validation script:

```text
scripts/verify-kafka-config-boundary.ps1
```

## Why ConfigMap

The Step 1 Kafka bootstrap server and topic names are non-secret configuration.

They belong in ConfigMap-style configuration because exposing them does not reveal credentials. Future TLS, SASL, MSK IAM auth, usernames, passwords, certificates, or tokens must not be placed here. Those belong in Secret or External Secrets Operator-managed Secret resources.

## Local Validation

Validate the repository contract:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-config-boundary.ps1
```

Makefile shortcut:

```powershell
make kafka-config-check
```

## Helm Render Validation

When Helm is available:

```powershell
make helm-cpemon-template
```

Then inspect the rendered ConfigMap:

```powershell
Select-String -Path build/helm/cpemon-rendered.yaml -Pattern "KAFKA_BOOTSTRAP_SERVERS"
Select-String -Path build/helm/cpemon-rendered.yaml -Pattern "cpemon.device.heartbeat.v1"
```

## Live Validation

After the CPEmon ConfigMap is applied:

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

If future workloads consume these as environment variables:

```powershell
kubectl get deploy -n cpemon cpemon-api -o yaml
kubectl get deploy -n cpemon acs-ingest -o yaml
kubectl get deploy -n cpemon cpemon-writer -o yaml
```

## Migration Boundary

The application should depend on:

```text
KAFKA_BOOTSTRAP_SERVERS
KAFKA_TOPIC_DEVICE_HEARTBEAT
KAFKA_TOPIC_WAN_STATUS
KAFKA_TOPIC_DEADLETTER
```

It should not depend on:

```text
Bitnami chart internals
StatefulSet names
Pod names
Kubernetes headless service details
MSK endpoint shape
```

That separation keeps a future migration to Strimzi or MSK mostly in deployment/configuration rather than application logic.

## Interview Summary

I treated Kafka bootstrap and topic names as configuration, not code. The Step 1 values are non-secret, so they live in the CPEmon ConfigMap boundary. Future authentication material would move through Secrets or External Secrets Operator. This keeps the application contract stable: producers should read `KAFKA_BOOTSTRAP_SERVERS` and topic-name variables, while the platform can later move from in-cluster Kafka to Strimzi or MSK behind the same config keys.
