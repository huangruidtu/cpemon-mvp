# Kafka Platform Introduction

## Why This Story Exists

`CCPU-8` introduces Kafka as the event-buffering platform for the CPEmon cloud upgrade.

The original MVP used MySQL queue tables to keep the demo small and complete. That was a deliberate MVP choice, not a statement that MySQL queues are the final architecture for a larger event-driven platform.

Story 8 starts the next phase:

```text
MVP queue table model
        |
        v
Kafka platform boundary
        |
        v
future application producer and consumer integration
```

The important sequencing decision is that Story 8 introduces the platform first. Application producer/consumer code comes later.

## CCPU-69: Kafka Deployment Option for Step 1

`CCPU-69` chooses the Kafka deployment option for the first Kafka platform step.

The ADR is:

```text
ADR/cloud-platform-upgrade-kafka-deployment-step1.md
```

## Decision

Use a Helm chart based Kafka installation for Step 1.

The target mental model is:

```text
EKS cluster
        |
        v
kafka namespace
        |
        v
Kafka installed by Helm
        |
        v
bootstrap service + initial topics
        |
        v
CPEmon applications in later stories
```

This is a platform-introduction decision. It does not yet implement application producers, consumers, event schemas, or a replacement for the current MySQL queue path.

## Why This Is the Right Step 1

The project already uses Helm for application packaging, so a Helm chart based Kafka install matches the existing learning path.

It gives the project a practical first milestone:

- choose the deployment model
- create the namespace boundary
- install or render Kafka resources
- define bootstrap configuration
- define initial topics
- validate produce/consume manually
- document the operational story

This is easier to learn, review, and explain than introducing Kafka, an operator, managed AWS networking, and application integration all at once.

## Option Comparison

| Option | Best For | Why Not First |
| --- | --- | --- |
| Helm chart based Kafka | Step 1 learning, EKS practice, render/install validation, small platform boundary | Less lifecycle automation than an operator. |
| Strimzi | Kubernetes-native Kafka lifecycle management, KafkaTopic/KafkaUser resources, stronger day-2 operations | Adds operator and CRD complexity before the basic CPEmon Kafka contract is proven. |
| Amazon MSK | Production managed Kafka direction, reduced broker operations, AWS-managed integration | Adds cost, networking, IAM, endpoint, and cloud-specific decisions too early. |

## Relationship to the MVP

The MVP ADR said not to use Kafka because the first version needed a small and reproducible demo.

The Step 1 cloud-platform decision says to introduce Kafka now because the project is moving toward a production-style event buffer.

The clean story is:

```text
MVP: choose MySQL queues for simplicity.
Step 1 platform upgrade: introduce Kafka with Helm for controlled learning.
Future hardening: consider Strimzi or MSK when lifecycle and production operations matter more.
```

That is a stronger interview answer than pretending Kafka was always required or that the MVP decision was wrong.

## Stable Contract

The broker deployment option should be hidden behind stable application-facing configuration:

```text
KAFKA_BOOTSTRAP_SERVERS
KAFKA_TOPIC_DEVICE_HEARTBEAT
KAFKA_TOPIC_WAN_STATUS
KAFKA_TOPIC_DEADLETTER
```

That means a future migration from in-cluster Kafka to Strimzi or MSK should mostly change deployment and configuration, not the application event-publishing design.

## What CCPU-69 Proves

This subtask proves:

- the Kafka deployment option is intentional
- the decision has tradeoffs
- the MVP no-Kafka decision and the cloud Kafka decision are compatible
- Strimzi and MSK are deferred for specific reasons
- later subtasks have a clear deployment direction

It does not prove:

- Kafka is installed
- topics exist
- produce/consume works
- application producers publish events
- consumers process events

Those are later subtasks in Story 8 and the following application-integration story.

## Interview Point

The strongest answer is that this is a phased migration. I did not add Kafka to the MVP because the MVP needed a small end-to-end proof. In the cloud-platform upgrade, Kafka becomes the event buffer, but I chose a Helm chart based deployment first so I could prove the namespace, install workflow, bootstrap config, topic plan, and validation path before changing application code. Strimzi and MSK remain future hardening options because the application should depend on stable Kafka configuration, not on one specific broker implementation.

## CCPU-70: Kafka Helm Installation Workflow

`CCPU-70` adds the Step 1 Kafka Helm installation workflow.

The values file is:

```text
k8s/addons/kafka/values.yaml
```

The runbook is:

```text
ops/runbooks/kafka-platform-helm.md
```

The Makefile targets are:

```text
make kafka-chart-show
make kafka-template
make kafka
make kafka-check
make kafka-validate
make kafka-helm-workflow-check
```

### Step 1 Values Boundary

The Step 1 values are deliberately conservative:

- one KRaft controller
- no separate broker replicas
- internal `ClusterIP` service
- no external access
- plaintext internal listener
- persistent storage enabled
- metrics disabled until the observability subtask

This is not a production Kafka design. It is the smallest useful platform install path that lets the project prove the namespace, release, service, and bootstrap contract.

### Bootstrap Contract

The initial internal bootstrap address is:

```text
kafka.kafka.svc.cluster.local:9092
```

Later application integration should consume this through configuration:

```text
KAFKA_BOOTSTRAP_SERVERS=kafka.kafka.svc.cluster.local:9092
```

The important design point is that the application should depend on a stable bootstrap value and topic names, not on the fact that the broker currently comes from the Bitnami chart.

### Validation Boundary

The repository can validate that the workflow files and Makefile targets exist with:

```powershell
make kafka-helm-workflow-check
```

Live render and install require Helm:

```powershell
make kafka-template
make kafka
make kafka-check
```

In the current local shell for `CCPU-70`, `helm` was not available on PATH, so this subtask documents the exact boundary instead of claiming live installation.

## CCPU-71: Kafka Namespace Boundary

`CCPU-71` documents and validates the Kubernetes namespace boundary for Kafka.

The namespace manifest is:

```text
k8s/base/namespaces.yaml
```

The runbook is:

```text
ops/runbooks/kafka-namespace.md
```

The validation script is:

```text
scripts/verify-kafka-namespace.ps1
```

The Makefile shortcut is:

```text
make kafka-namespace-check
```

### Namespace Labels

The `kafka` namespace uses:

```yaml
app.kubernetes.io/part-of: cpemon-mvp
app.kubernetes.io/name: kafka
cpemon.io/layer: data-streaming
cpemon.io/managed-by: gitops-ready-manifest
```

### Why Kafka Is Isolated

Kafka is a platform data-streaming dependency. It should not live in the same namespace as CPEmon application Deployments.

The separate namespace gives a clearer boundary for:

- Helm release ownership
- persistent volume troubleshooting
- NetworkPolicy and RBAC
- observability selection
- future Strimzi migration
- separating application operations from platform operations

### Validation Boundary

Local validation proves the namespace is declared correctly in Git:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-namespace.ps1
```

Live validation requires a Kubernetes cluster:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
kubectl get ns kafka --show-labels
```

## CCPU-72: Initial Kafka Topics

`CCPU-72` defines the first CPEmon Kafka topics.

The topic contract is in:

```text
k8s/addons/kafka/values.yaml
```

The runbook is:

```text
ops/runbooks/kafka-topics.md
```

The validation script is:

```text
scripts/verify-kafka-topics.ps1
```

The Makefile shortcut is:

```text
make kafka-topics-check
```

### Initial Topics

| Topic | Purpose |
| --- | --- |
| `cpemon.device.heartbeat.v1` | Device heartbeat events from CPE/ACS ingestion. |
| `cpemon.wan.status.v1` | WAN status events for connectivity and dashboard updates. |
| `cpemon.deadletter.v1` | Failed or unprocessable events for debugging and replay decisions. |

### Step 1 Topic Settings

For Step 1, each topic uses:

```text
partitions: 1
replicationFactor: 1
retention.ms: 604800000
```

This matches the small one-controller Kafka learning environment. Production Kafka would revisit partition count, replication factor, retention, compaction, and dead-letter policies.

### Why Define Topics Before Producers

Topic names are platform contracts.

Defining them before writing producer code prevents accidental hardcoded event routing and makes the future app integration clearer:

```text
platform defines topic contract
        |
        v
application reads topic names from config
        |
        v
producer publishes to approved topics
```

### Validation Boundary

Local validation proves the topic contract exists in Git:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-topics.ps1
```

Live validation requires Kafka to be installed and ready:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-topics.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --list
```

## CCPU-73: Kafka Bootstrap and Topic Config Boundary

`CCPU-73` adds the application-facing Kafka configuration boundary.

The Helm values are:

```text
deploy/helm/cpemon/values.yaml
```

The Helm ConfigMap template is:

```text
deploy/helm/cpemon/templates/configmap.yaml
```

The raw manifest bridge is:

```text
k8s/app/cpemon-app-config.yaml
```

The runbook is:

```text
ops/runbooks/kafka-bootstrap-config.md
```

The validation script is:

```text
scripts/verify-kafka-config-boundary.ps1
```

### Config Keys

| Key | Value |
| --- | --- |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka.kafka.svc.cluster.local:9092` |
| `KAFKA_TOPIC_DEVICE_HEARTBEAT` | `cpemon.device.heartbeat.v1` |
| `KAFKA_TOPIC_WAN_STATUS` | `cpemon.wan.status.v1` |
| `KAFKA_TOPIC_DEADLETTER` | `cpemon.deadletter.v1` |

These values are non-secret. They belong in ConfigMap-style application configuration.

Future auth material does not belong here. TLS keys, SASL credentials, tokens, or MSK IAM-specific secret material should use Secret references or External Secrets Operator.

### Why This Boundary Matters

Application code should depend on stable config keys, not broker implementation details.

That keeps this path open:

```text
Bitnami chart Kafka
        |
        v
same KAFKA_BOOTSTRAP_SERVERS key
        |
        v
future Strimzi or MSK endpoint
```

The config value can change later without changing the application API.

### Validation Boundary

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-config-boundary.ps1
```

Live validation requires rendered or applied ConfigMaps:

```powershell
make helm-cpemon-template
kubectl get configmap cpemon-app-config -n cpemon -o yaml
```

## CCPU-74: Manual Produce and Consume Validation

`CCPU-74` captures the manual Kafka produce/consume validation path.

The runbook is:

```text
ops/runbooks/kafka-produce-consume-validation.md
```

The validation script is:

```text
scripts/verify-kafka-produce-consume-runbook.ps1
```

The Makefile shortcut is:

```text
make kafka-produce-consume-runbook-check
```

### What It Proves

A manual produce/consume test proves the Kafka platform path:

```text
test message
        |
        v
kafka-console-producer.sh
        |
        v
cpemon.device.heartbeat.v1
        |
        v
kafka-console-consumer.sh
        |
        v
same message returned
```

It proves broker/topic connectivity. It does not prove CPEmon application producer behavior.

### Test Message

The runbook uses:

```json
{"source":"manual-kafka-validation","serialNumber":"TEST-CPE-0001","status":"online","ts":"2026-06-21T00:00:00Z"}
```

This is intentionally not the final application event schema.

### Validation Boundary

Local validation proves the runbook exists and contains the required commands:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-produce-consume-runbook.ps1
```

Live validation requires Kafka to be installed and ready:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-console-consumer.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --topic cpemon.device.heartbeat.v1 `
  --from-beginning `
  --max-messages 1
```

## CCPU-75: Topic Naming Convention

`CCPU-75` documents the CPEmon Kafka topic naming convention.

The convention document is:

```text
docs/knowledge/kafka-topic-naming-convention.md
```

The validation script is:

```text
scripts/verify-kafka-topic-naming.ps1
```

The Makefile shortcut is:

```text
make kafka-topic-naming-check
```

### Pattern

Use:

```text
cpemon.<domain>.<event-family>.v<major>
```

Current examples:

```text
cpemon.device.heartbeat.v1
cpemon.wan.status.v1
cpemon.deadletter.v1
```

### Design Rules

- Topic names are logical event contracts, not broker implementation details.
- Do not include environment names in topic names.
- Do not include producer service names unless the topic is truly service-owned.
- Include a major version suffix for compatibility management.
- Treat dead-letter naming as an operational decision, not an afterthought.

### Interview Point

Topic naming matters because names become long-lived contracts between producers, consumers, dashboards, runbooks, alerts, and replay tools. A good topic name explains the business domain and compatibility version without leaking cluster, chart, environment, or producer implementation details.

## CCPU-159: Kafka Architecture and Migration Decision

`CCPU-159` documents where Kafka fits in CPEmon and why Story 8 does not immediately replace the application queue behavior.

The ADR is:

```text
ADR/cloud-platform-upgrade-kafka-platform-architecture.md
```

The knowledge note is:

```text
docs/knowledge/kafka-platform-architecture-migration.md
```

The validation script is:

```text
scripts/verify-kafka-architecture-docs.ps1
```

The Makefile shortcut is:

```text
make kafka-architecture-docs-check
```

### Migration Boundary

The migration is:

```text
current MySQL queue path remains baseline
        |
        v
Kafka platform contract is introduced
        |
        v
manual Kafka validation proves platform readiness
        |
        v
future application story adds producers and consumers
        |
        v
MySQL queue behavior is retired only after Kafka path is proven
```

This is the core Story 8 architecture answer: Kafka is introduced as a platform event buffer first, not as a hidden application rewrite.

## CCPU-160: Validation and Observability Boundary

`CCPU-160` captures the overall Kafka validation and observability boundary.

The runbook is:

```text
ops/runbooks/kafka-validation-observability.md
```

The validation script is:

```text
scripts/verify-kafka-validation-observability.ps1
```

The Makefile shortcut is:

```text
make kafka-validation-observability-check
```

### Validation Layers

There are two different claims:

| Layer | Claim |
| --- | --- |
| Repository validation | Files, values, docs, scripts, and config contracts exist. |
| Live validation | Kafka runs in a cluster and can serve topics, produce/consume, logs, and metrics. |

Story 8 documentation keeps these separate.

### Observability Boundary

The Step 1 Kafka values keep metrics disabled while the platform contract is introduced.

Future Kafka observability should include:

- broker readiness and restarts
- PVC health
- topic traffic
- consumer group lag
- dead-letter topic traffic
- ServiceMonitor or exporter integration

The project should not claim Prometheus Kafka metrics until an exporter and ServiceMonitor are enabled and scraped.
