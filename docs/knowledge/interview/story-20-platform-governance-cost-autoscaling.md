# Story 20 - Platform Governance, Cost Visibility, and Basic Autoscaling

## Interview Narrative

I added the first platform operations layer around CPEmon. Kyverno provides
policy-as-code guardrails, OpenCost makes namespace cost visible, and HPA gives
`cpemon-api` a basic Kubernetes-native scale-out path. I intentionally kept the
scope conservative so the first version is teachable and verifiable.

## Q1: What problem does this story solve?

It moves the platform beyond deployment. A useful platform should also prevent
common unsafe workloads, expose cost signals, and support basic scaling. This
story adds those three operational capabilities without pretending to solve all
security, FinOps, or autoscaling requirements at once.

## Q2: Why include Kyverno?

Kyverno gives Kubernetes policy as code. It can validate resources before they
become cluster state, which is useful for baseline rules such as requiring
resources, banning `latest` tags, requiring labels, and requiring non-root
containers where compatible.

## Q3: Why include OpenCost?

OpenCost gives namespace and workload cost visibility. For CPEmon, that matters
because the platform now has application, Kafka, monitoring, Argo CD, Kyverno,
and OpenCost namespaces. Step 1 is about seeing cost before trying to optimize
or allocate it.

## Q4: Why start with HPA instead of KEDA?

HPA is Kubernetes-native and enough for a first API scaling story. `cpemon-api`
can scale from CPU pressure once requests and metrics-server exist. KEDA is
better for event-driven signals like Kafka lag, so it belongs in Step 2 after
the basic HPA path is proven.

## Q5: What is platform-owned vs application-owned?

The platform owns Kyverno installation, shared policies, OpenCost installation,
cost runbooks, and platform validation. The application owns resource requests,
labels, image tags, and workload-specific HPA values. The platform gives
guardrails; the application satisfies them.

## Q6: What is intentionally out of scope?

Full policy hardening, production chargeback, custom metrics autoscaling,
predictive scaling, and KEDA are out of scope. The story focuses on a minimal
baseline that can be explained, tested, and extended later.

## Q7: How would you validate this story?

Offline, I would render and lint Helm charts and run repository verifier
scripts. In a dev cluster, I would check Kyverno pods and policies, policy
reports, OpenCost pods and UI/API access, and the `cpemon-api` HPA status.

## Q8: What is the 60-second interview answer?

I added a platform operations baseline: Kyverno for policy-as-code governance,
OpenCost for namespace cost visibility, and HPA for basic `cpemon-api`
autoscaling. The key tradeoff is scope control: enforce the most valuable
guardrails first, expose cost before optimizing it, and use HPA before adding
KEDA for event-driven scaling.
