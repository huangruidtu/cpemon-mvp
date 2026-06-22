# ADR: HPA First, KEDA Step 2

## Status

Accepted

## Context

Story 20 introduces basic autoscaling for the CPEmon platform. The platform now
has GitOps-managed governance, cost visibility, and a first autoscaling path for
`cpemon-api`.

There are two common autoscaling options:

* Kubernetes HorizontalPodAutoscaler
* KEDA event-driven autoscaling

HPA is enough for the first `cpemon-api` scaling story because the initial
signal is CPU utilization. KEDA becomes useful when the scaling signal is an
event source, such as Kafka consumer lag, queue depth, or an external metric.

## Decision

Use HPA first for `cpemon-api`.

Defer KEDA to Step 2.

## Rationale

HPA is the right first step because:

* it is Kubernetes-native
* it depends only on metrics-server and resource requests for CPU scaling
* it has a small operational footprint
* it is easier to validate in a dev cluster
* it matches the current `cpemon-api` scaling signal

KEDA is deferred because:

* it adds another controller and CRD surface
* the current story does not require event-source scaling
* Kafka consumer lag scaling belongs closer to `cpemon-writer`
* queue-depth scaling belongs closer to intake or background worker workloads
* introducing it early would blur the learning objective

## Future KEDA Candidates

KEDA should be reconsidered when one of these signals becomes the primary
scaling driver:

```text
cpemon-writer replicas from Kafka consumer lag
acs-ingest replicas from intake backlog
worker replicas from queue depth
scheduled scale windows for known maintenance or reporting periods
external metrics from Prometheus or cloud services
```

## Guardrails For Step 2

Before adding KEDA, the project should have:

* stable Kafka metrics
* clear consumer group ownership
* known lag thresholds
* dashboards for lag and processing rate
* rollback instructions for ScaledObject changes
* cost review for replica growth

## Consequences

Positive:

* Step 1 autoscaling remains simple and teachable.
* HPA can be validated with the existing Helm chart.
* The platform avoids another controller until there is a real event-driven
  scaling need.

Tradeoffs:

* CPU is not a perfect scaling signal for asynchronous Kafka workloads.
* Step 1 does not autoscale directly from Kafka lag.
* A future KEDA story must add controller installation, ScaledObject templates,
  and event-source validation.

## Interview Answer

```text
I chose HPA first because cpemon-api needed a conservative CPU-based scaling
path, and HPA is Kubernetes-native. I deferred KEDA because KEDA is most useful
when the scaling signal is event-driven, such as Kafka lag for cpemon-writer.
That keeps the first autoscaling story small and leaves a clear Step 2 when the
platform has stable Kafka metrics and lag thresholds.
```
