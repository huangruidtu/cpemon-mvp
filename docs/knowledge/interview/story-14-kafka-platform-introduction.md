# Story 14: Kafka Platform Introduction

## Q1: What is the goal of Story 8 / CCPU-8?

The goal is to introduce Kafka as the platform event buffer for the CPEmon cloud upgrade.

This story focuses on the platform boundary:

- deployment option
- namespace
- installation workflow
- bootstrap server contract
- initial topics
- manual validation
- documentation and interview notes

It does not yet implement application producer or consumer code.

## Q2: What did CCPU-69 decide?

`CCPU-69` decided to use a Helm chart based Kafka deployment for Step 1.

The ADR is:

```text
ADR/cloud-platform-upgrade-kafka-deployment-step1.md
```

## Q3: Why not use Kafka in the original MVP?

The MVP needed to be small, reproducible, and easy to demo end to end.

Kafka would have added brokers, topics, partitions, storage, networking, and monitoring before the basic CPEmon flow was proven.

For the MVP, MySQL queue tables were good enough to demonstrate durable buffering and background processing.

## Q4: Why introduce Kafka now?

The project has moved from MVP demonstration into cloud platform upgrade.

Kafka gives a better event-driven architecture story:

- durable event log
- producer/consumer decoupling
- replay potential
- partitioning and scaling path
- clearer topic ownership and retention model
- stronger alignment with platform and data-engineering patterns

## Q5: Why choose a Helm chart based Kafka deployment first?

Because it fits the Step 1 learning path.

The project already uses Helm, and the first Kafka task should be small enough to render, install, validate, and explain.

A Helm chart based install lets me focus on:

- Kafka namespace
- chart values
- bootstrap service
- topic plan
- manual produce/consume validation
- operational documentation

without immediately adding operator-specific or managed-service complexity.

## Q6: Why not Strimzi first?

Strimzi is a strong future option, but it introduces an operator and Kafka-specific CRDs.

That is valuable when lifecycle management becomes the priority:

- Kafka cluster reconciliation
- KafkaTopic resources
- KafkaUser resources
- certificate and listener management
- upgrade workflows

For Step 1, the project first needs to prove the simpler Kafka platform contract.

## Q7: Why not Amazon MSK first?

MSK is a strong production direction, but it adds cloud-specific decisions early:

- VPC and subnet placement
- security groups
- endpoint access
- cost
- IAM and authentication choices
- Terraform module scope

Those decisions are real, but they are better handled after the project has stable topic names, bootstrap configuration, and application integration boundaries.

## Q8: What is the key abstraction that keeps future migration possible?

The key abstraction is the bootstrap and topic configuration contract.

The application should depend on configuration such as:

```text
KAFKA_BOOTSTRAP_SERVERS
KAFKA_TOPIC_DEVICE_HEARTBEAT
KAFKA_TOPIC_WAN_STATUS
KAFKA_TOPIC_DEADLETTER
```

If those values are stable, the broker implementation can move from Helm chart Kafka to Strimzi or MSK with less application impact.

## Q9: What does CCPU-69 prove?

It proves the deployment decision is intentional and scoped.

It proves why the project starts with Helm chart Kafka, why Strimzi and MSK are deferred, and how this decision fits the earlier MVP no-Kafka decision.

It does not prove live Kafka installation or application event publishing.

## Q10: What is the validation boundary for CCPU-69?

CCPU-69 is a decision and documentation task.

It validates:

- ADR exists
- tradeoffs are documented
- knowledge notes exist
- interview questions exist

It does not validate:

- broker pods running
- topics created
- produce/consume success
- application code publishing Kafka events

Those belong to later subtasks.

## Q11: How would you explain this in 60 seconds?

The original CPEmon MVP deliberately avoided Kafka because the first goal was an end-to-end demo, not a distributed streaming platform. It used MySQL queue tables as a simple durable buffer. In the cloud-platform upgrade, Kafka becomes the event-buffering layer, but I introduced it in phases. For Step 1, I chose a Helm chart based Kafka deployment because the project already uses Helm and I wanted to prove the namespace, install workflow, bootstrap config, topic plan, and manual validation before changing application code. Strimzi is a good future option for Kubernetes-native Kafka lifecycle management, and MSK is a good production direction for managed broker operations. The stable boundary is `KAFKA_BOOTSTRAP_SERVERS` and topic configuration, so the application can move between broker deployment models later.

## Q12: What is the main tradeoff in the decision?

The tradeoff is speed and learning clarity versus production-grade lifecycle management.

A Helm chart based deployment is easier to start with and fits the current project. Strimzi or MSK may be better for later production hardening, but choosing them immediately would expand the first Kafka story too much.

## STAR Story

Situation:

CPEmon started as an MVP that used MySQL queue tables instead of Kafka so the first demo could stay small and complete.

Task:

In the cloud-platform upgrade, I needed to introduce Kafka as a more realistic event buffer without mixing platform setup, managed service design, and application integration into one large task.

Action:

I chose a Helm chart based Kafka deployment for Step 1, documented why it fits the current EKS and Helm learning path, and explicitly deferred Strimzi and MSK until lifecycle automation or managed production operations become the main concern.

Result:

The project now has a clear Kafka migration sequence: prove the platform boundary first, then add topics and validation, then integrate application producers and consumers, and later consider Strimzi or MSK behind the same bootstrap/topic contract.
