# Kafka Platform Learning Notes

## Purpose

These notes are the interview-focused summary for CPEmon Story 8.

Covered task:

- `CCPU-161`: Add Kafka interview learning notes.

Use this as the quick review sheet before interviews. Use `story-14-kafka-platform-introduction.md` for the full Q&A set.

## 60-Second Story

CPEmon started as a Kubernetes MVP that used MySQL queue tables for durable buffering. That was intentional because the first goal was a small, complete demo. In the cloud-platform upgrade, Kafka becomes the event-buffering platform, but I introduced it in phases. First I chose a Helm chart based Kafka deployment, then documented the namespace, values, topics, bootstrap config, topic naming convention, produce/consume validation, and observability boundary. I did not immediately replace the MySQL queue because platform readiness and application behavior should be validated separately. Later, producers and consumers can be added behind stable config keys like `KAFKA_BOOTSTRAP_SERVERS` and topic-name variables.

## Core Mental Model

```text
MVP:
ingest service -> MySQL queue table -> writer -> MySQL business table

Story 8:
Kafka platform contract is introduced and validated manually

Future:
ingest service -> Kafka topic -> consumer/writer -> MySQL business table
```

Kafka replaces the event-buffer role, not the business database role.

## Key Concepts

Broker:
A Kafka server that stores topic partitions and serves producers and consumers.

Topic:
A named event stream. In CPEmon, examples are `cpemon.device.heartbeat.v1` and `cpemon.wan.status.v1`.

Partition:
An ordered shard of a topic. Partitions are the unit of parallelism and ordering.

Replication:
Copies of partitions across brokers for availability. Step 1 uses replication factor one because it is a small learning deployment.

Bootstrap server:
The initial Kafka endpoint clients use to discover the cluster. CPEmon uses `KAFKA_BOOTSTRAP_SERVERS`.

Producer:
Code or tooling that writes events to Kafka.

Consumer:
Code or tooling that reads events from Kafka.

Consumer group:
A group of consumers that share work for a topic. Lag is usually measured per group.

Retention:
How long Kafka keeps events. Step 1 uses seven days for initial topics.

Dead-letter topic:
A topic for events that cannot be processed safely after validation or retries.

## Decisions to Remember

| Decision | Why |
| --- | --- |
| Helm chart based Kafka first | Fits current Helm/EKS learning path and keeps Story 8 manageable. |
| Strimzi deferred | Better later when Kafka lifecycle automation is the main problem. |
| MSK deferred | Better later when managed production broker operations are needed. |
| Kafka namespace | Keeps data-streaming platform resources separate from CPEmon app resources. |
| Topic names in config | Prevents hardcoded topic strings in future application code. |
| Manual produce/consume first | Proves platform connectivity before application integration. |
| MySQL queue not removed yet | Avoids mixing platform risk with app behavior and data consistency risk. |

## Topic Contract

Pattern:

```text
cpemon.<domain>.<event-family>.v<major>
```

Initial topics:

```text
cpemon.device.heartbeat.v1
cpemon.wan.status.v1
cpemon.deadletter.v1
```

Do not include:

- environment names
- chart names
- broker names
- producer service names

## Config Contract

```text
KAFKA_BOOTSTRAP_SERVERS=kafka.kafka.svc.cluster.local:9092
KAFKA_TOPIC_DEVICE_HEARTBEAT=cpemon.device.heartbeat.v1
KAFKA_TOPIC_WAN_STATUS=cpemon.wan.status.v1
KAFKA_TOPIC_DEADLETTER=cpemon.deadletter.v1
```

These are non-secret values. Future TLS, SASL, tokens, or MSK auth material should use Secrets or External Secrets Operator.

## Validation Story

Repository validation proves:

- values files exist
- topic names are configured
- ConfigMap keys exist
- runbooks exist
- interview docs exist

Live validation proves:

- namespace exists
- Helm release is deployed
- Kafka pods are Ready
- PVCs are Bound
- topics exist
- produce/consume works
- logs and metrics can be inspected

## Debugging Order

Use this order when Kafka is broken:

```text
namespace
  -> Helm release
  -> pods
  -> service
  -> PVC/storage
  -> topics
  -> broker logs
  -> producer command
  -> consumer command
  -> application integration
```

This prevents blaming application code before the platform is ready.

## Strong Interview Answers

Why did you not use Kafka in the MVP?

Because the MVP needed a small, complete, reproducible demo. MySQL queue tables were enough to show durable buffering and background processing. Kafka would have added operational complexity before the core CPEmon flow was proven.

Why introduce Kafka now?

Because the cloud-platform upgrade needs a stronger event-buffer story: retention, replay potential, producer/consumer decoupling, consumer scaling, lag visibility, and dead-letter handling.

Why Helm chart first?

Because the project already uses Helm, and the first Kafka story should prove the platform contract without introducing operator or managed-service complexity too early.

Why not replace the MySQL queue immediately?

Because that would mix Kafka platform risk with producer/consumer code risk and data consistency risk. I separated platform readiness from application integration.

What is the most important boundary?

The app should depend on config keys such as `KAFKA_BOOTSTRAP_SERVERS` and topic-name variables, not on Bitnami chart internals or pod/service implementation details.

## STAR Story

Situation:

CPEmon had a working MVP using MySQL queue tables for buffering, but the cloud-platform upgrade needed a more realistic event-driven architecture.

Task:

Introduce Kafka safely without turning one story into a full application rewrite.

Action:

I chose a Helm chart based Kafka deployment for Step 1, created the Kafka namespace and values contract, defined initial topics, exposed bootstrap/topic config keys, documented manual produce/consume validation, wrote topic naming rules, and captured observability and migration boundaries.

Result:

The project now has a Kafka platform contract that can be validated independently. Application producers and consumers can be added later behind stable config keys, and the MySQL queue path can remain until Kafka integration is proven.

## One-Line Resume Version

Introduced Kafka as a phased event-buffering platform for CPEmon on EKS by defining Helm-based deployment, namespace, topics, bootstrap config, validation runbooks, and interview-ready migration documentation before application producer/consumer integration.
