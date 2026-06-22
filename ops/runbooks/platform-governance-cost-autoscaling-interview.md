# Platform Governance, Cost, and Autoscaling Interview Notes

This note turns Story 20 into an interview-ready explanation.

## One-Minute Story

```text
I added the first platform-control layer for CPEmon. Kyverno provides
policy-as-code guardrails, OpenCost gives namespace-level cost visibility, and
HPA gives cpemon-api a conservative CPU-based autoscaling path. I kept the
scope intentionally small: visibility before chargeback, HPA before KEDA, and
baseline policies before a large compliance program.
```

## Why These Tools

Kyverno:

```text
Kubernetes-native policy-as-code. Good for validating image tags, labels,
security context, and resource requests without introducing a separate policy
language.
```

OpenCost:

```text
Cost visibility from Kubernetes usage metrics. Good first FinOps step because
it shows namespace and workload cost before the team discusses chargeback.
```

HPA:

```text
Kubernetes-native autoscaling for CPU-based API load. It is enough for the first
cpemon-api scaling path.
```

KEDA:

```text
Deferred until event-driven scaling is required, especially Kafka consumer lag
for cpemon-writer.
```

## Strong Interview Framing

Use this structure:

```text
Problem -> Decision -> Tradeoff -> Validation -> Future work
```

Example:

```text
The problem was that the platform was gaining more moving parts, so I added a
small control layer. I chose Kyverno for policy guardrails, OpenCost for cost
visibility, and HPA for basic API autoscaling. I avoided KEDA in Step 1 because
there was no event-driven scaling requirement yet. I validated with local
manifest checks and documented live cluster checks separately. Future work is
KEDA for Kafka lag once the metrics and thresholds are stable.
```

## Questions To Practice

1. Why did you add Kyverno?
2. What policies did you start with?
3. Why did you start OpenCost with namespace allocation?
4. Why is cost visibility not the same as chargeback?
5. Why does HPA need resource requests?
6. How does HPA work with Argo Rollouts?
7. Why not use KEDA immediately?
8. What would trigger a future KEDA implementation?
9. How would you validate this in a live dev cluster?
10. What did you intentionally defer?

## Best Short Answers

Why Kyverno?

```text
Because it lets us express Kubernetes guardrails as GitOps-managed YAML and
catch platform hygiene issues like missing resources, latest tags, missing
labels, and root containers early.
```

Why OpenCost?

```text
Because once CPEmon has separate namespaces for app, Kafka, monitoring, GitOps,
governance, and cost visibility, we need to see where spend comes from before
we optimize or assign ownership.
```

Why HPA first?

```text
Because cpemon-api has a simple CPU-based scaling need, and HPA is native,
small, and easy to validate.
```

Why KEDA later?

```text
Because KEDA is strongest when the scaling signal is event-driven. The best
future CPEmon candidate is cpemon-writer from Kafka consumer lag, but that needs
stable lag metrics and threshold decisions first.
```

## Red Flags To Avoid

Avoid saying:

```text
OpenCost implements chargeback.
HPA proves production capacity.
KEDA is always better than HPA.
Kyverno makes the platform fully compliant.
```

Say instead:

```text
OpenCost starts cost visibility.
HPA proves a conservative autoscaling path.
KEDA is better when events are the scaling signal.
Kyverno starts with baseline guardrails.
```
