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
