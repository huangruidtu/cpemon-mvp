# ADR: Kafka Deployment Option for Step 1

## Status

Accepted for CCPU-69.

## Context

The original CPEmon MVP intentionally avoided Kafka. It used MySQL-backed queue tables because the first goal was to prove an end-to-end monitoring path with a small lab footprint:

```text
CPE simulator -> ACS / ingest API -> MySQL queue tables -> cpemon-writer -> dashboards
```

That decision is still valid for the MVP. Story 8 changes the learning target. CPEmon is now moving into a cloud-platform upgrade phase where the project should demonstrate a more production-style event buffer and streaming boundary.

The question for CCPU-69 is:

```text
What Kafka deployment option should CPEmon use for Step 1?
```

The practical options are:

- a Helm chart based Kafka installation in EKS
- an operator-managed Kafka platform such as Strimzi
- a managed Kafka service such as Amazon MSK

## Decision

Use a Helm chart based Kafka installation for Step 1.

For this project, that means:

```text
Terraform creates EKS
        |
        v
Kubernetes namespace kafka
        |
        v
Helm installs a small Kafka deployment
        |
        v
CPEmon topics and bootstrap service contract
        |
        v
Application integration in a later story
```

The Step 1 Kafka work should focus on:

- platform installation workflow
- namespace boundary
- bootstrap server contract
- initial topic plan
- manual produce/consume validation
- documentation, runbooks, and interview notes

It should not immediately implement application producers, consumers, or schemas. Those belong to a later application-integration story.

## Why Helm Chart Based Kafka First

A Helm chart based Kafka deployment is the best Step 1 choice because it keeps the platform introduction small enough to implement, validate, and explain.

It fits the current project because:

- Helm is already part of the CPEmon deployment model.
- Story 8 is a learning and migration step, not the final production Kafka design.
- A chart-based install is easy to render, review, and document.
- It keeps the operational surface smaller than adopting a full Kafka operator immediately.
- It allows topic, bootstrap, and validation contracts to be designed before application code depends on Kafka.

This is the same migration principle used in earlier stories:

```text
stabilize the platform contract first
then move application behavior behind that contract
```

## Why Not Strimzi First

Strimzi is a strong Kubernetes-native Kafka operator. It is a good future option when the project needs stronger lifecycle management for Kafka clusters, topics, users, certificates, upgrades, and day-2 operations.

It is not the Step 1 choice because:

- it adds custom resources and operator behavior before the basic Kafka boundary is proven
- it increases the number of Kubernetes concepts to explain in the first Kafka story
- it makes the first validation path depend on operator reconciliation in addition to Kafka itself
- it is better introduced after the project already has a clear topic and bootstrap contract

The future migration path remains open:

```text
Helm chart Kafka for Step 1
        |
        v
Strimzi when Kafka lifecycle automation becomes the main concern
```

## Why Not MSK First

Amazon MSK is the stronger production direction when the project needs managed broker operations, AWS integration, and reduced self-managed Kafka maintenance.

It is not the Step 1 choice because:

- it adds AWS networking, cost, IAM, security group, and endpoint decisions too early
- live validation would depend on cloud resources instead of a repeatable Kubernetes learning workflow
- the project has not yet implemented the application producer/consumer boundary
- MSK migration is easier to explain after topic names, bootstrap config, and event contracts already exist

The future production direction can still be:

```text
application uses KAFKA_BOOTSTRAP_SERVERS
        |
        v
bootstrap value changes from in-cluster Kafka to MSK endpoint
        |
        v
application code stays stable
```

## Relationship to the MVP No-Kafka ADR

The earlier MVP decision was:

```text
Do not use Kafka in the first MVP.
Use MySQL queue tables to keep the demo small and complete.
```

The Step 1 platform decision is:

```text
Introduce Kafka as the cloud-platform event buffer.
Start with a Helm chart based install before application integration.
```

These decisions do not conflict. They describe different phases:

| Phase | Decision | Reason |
| --- | --- | --- |
| MVP | No Kafka | Keep the first demo small, inspectable, and reproducible. |
| Cloud platform Step 1 | Kafka via Helm | Introduce a realistic event buffer while keeping implementation scope controlled. |
| Future hardening | Strimzi or MSK | Improve lifecycle management or move broker operations to a managed AWS service. |

## Consequences

Positive:

- The Kafka introduction is achievable inside the current Helm/EKS learning path.
- The project can document Kafka topics and bootstrap configuration before changing application code.
- Local render validation and live cluster validation can be separated cleanly.
- Future Strimzi or MSK migration remains possible through the same bootstrap/topic contract.

Trade-offs:

- A Helm chart does not provide the same Kafka-specific lifecycle management as Strimzi.
- Self-managed Kafka on EKS still requires broker, storage, networking, and observability care.
- This does not prove production-grade Kafka operations.
- A later story must decide when to move from Step 1 Kafka to Strimzi or MSK.

## Validation Boundary

CCPU-69 validates the deployment decision and documents the tradeoffs.

It does not validate:

- live Kafka installation
- topic creation
- broker readiness
- manual produce/consume
- application producer or consumer behavior
- MSK connectivity

Those belong to later Story 8 subtasks.

## Interview Answer

I chose a Helm chart based Kafka deployment for Step 1 because the goal was to introduce Kafka as a platform boundary without overloading the first Kafka story. The original MVP intentionally avoided Kafka and used MySQL queues to keep the demo small. In the cloud-platform upgrade, Kafka becomes the event buffer, but I first wanted to prove the deployment, namespace, bootstrap config, topic plan, and validation workflow. Strimzi is a good future option when Kafka lifecycle automation becomes the priority, and MSK is a strong production direction when managed broker operations and AWS integration matter more. The key is that the application should depend on stable topic names and `KAFKA_BOOTSTRAP_SERVERS`, not on the specific broker deployment option.

## References

- `ADR/no-kafka-in-mvp.md`
- `ADR/cloud-platform-upgrade-eks-terraform-gitops-kafka.md`
