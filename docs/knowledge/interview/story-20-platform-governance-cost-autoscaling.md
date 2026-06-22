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

## Q9: What did CCPU-200 add?

It added the Kyverno control plane as a GitOps-managed platform add-on. The
`kyverno-dev` Argo CD Application pins the Kyverno Helm chart to `3.8.1`, reads
values from `k8s/addons/kyverno/values.yaml`, and deploys into the `kyverno`
namespace. The AppProject was updated with only the required chart repo and
destination namespace.

## Q10: Why separate Kyverno installation from Kyverno policies?

The controller and the policies have different risk profiles. Installing
Kyverno introduces CRDs, controllers, RBAC, and admission webhooks. Policies
decide what workloads are accepted or rejected. Keeping them in separate
subtasks makes review easier and lets an operator validate the policy engine
before enforcing CPEmon-specific rules.

## Q11: Why is Kyverno not installed inside the CPEmon Helm chart?

Kyverno is shared platform infrastructure. If every application installed its
own policy engine, policy ownership would be fragmented and upgrades would be
dangerous. The platform owns Kyverno once; applications satisfy the policies.

## Q12: What should you check after syncing `kyverno-dev`?

Check the Application health, Kyverno pods in the `kyverno` namespace, Kyverno
CRDs, and admission webhook configurations. Only after the controller is healthy
should the team sync `ClusterPolicy` resources.

## Q13: What did CCPU-201 add?

It added the first CPEmon Kyverno `ClusterPolicy`:
`cpemon-require-container-resources`. The policy requires CPU and memory
requests and limits for containers in Pods created in the `cpemon` namespace.
It also added `kyverno-policies-dev`, a separate Argo CD Application for the
policy package.

## Q14: Why are requests and limits a governance concern?

They affect more than raw resource use. CPU requests drive scheduler placement
and HPA utilization calculations. Memory limits reduce blast radius. Resource
intent also makes OpenCost data easier to interpret. A platform that allows
workloads without requests and limits cannot make reliable scheduling, scaling,
or cost decisions.

## Q15: Why use `Enforce` for this policy?

This policy is narrow and high-value: it targets CPEmon Pods and checks fields
the application should already provide. Enforcing it prevents bad workload
manifests from becoming cluster state. Broader or more disruptive policies can
start in audit mode later, but this baseline is safe to make a hard contract.

## Q16: Why create `kyverno-policies-dev` instead of putting policies in the
same Application as Kyverno?

The controller and policies fail differently. If the controller chart has a
problem, rollback is a platform add-on rollback. If a policy is too strict,
rollback is a policy package rollback. Separate Applications make sync order,
review, and rollback easier to explain and operate.
