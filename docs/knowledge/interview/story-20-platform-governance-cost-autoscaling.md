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

## Q17: What did CCPU-202 add?

It added `ClusterPolicy/cpemon-disallow-latest-image-tag`, which rejects Pods
in the `cpemon` namespace when any container image uses the mutable `:latest`
tag. It also added the runbook, verifier, knowledge notes, and interview
material for explaining image tag governance.

## Q18: Why is `latest` dangerous in GitOps?

GitOps assumes Git describes the desired state. If an image tag is mutable, the
same Git commit can deploy different image contents at different times. That
makes rollback, audit, and incident analysis much weaker.

## Q19: Why not require digests immediately?

Digest-only images are stronger, but they add workflow friction and require CI
promotion discipline. For this learning platform, banning `latest` removes the
highest-risk mutable tag first. Digest-only or image-signature policies can be
a future production hardening step.

## Q20: What did CCPU-203 add?

It added two Kyverno policies: one requires standard `app.kubernetes.io/*`
labels on CPEmon Pods, and one requires containers to run as non-root with
privilege escalation disabled. It also updated the CPEmon Helm chart so the
rendered application workloads satisfy the non-root policy by default.

## Q21: Why are labels a platform governance issue?

Labels are the shared index for Kubernetes operations. Argo CD, kubectl,
Prometheus, cost tools, and incident runbooks all rely on stable labels to find
and group resources. Requiring labels prevents unowned or hard-to-debug
workloads from drifting into the platform.

## Q22: Why update the Helm chart in the same task?

A policy that blocks the current application is a broken rollout plan. The
right sequence is to add the guardrail and make the application comply in the
same change. That proves the rule is realistic, not just theoretical.

## Q23: Is this full Kubernetes security hardening?

No. It is a baseline. Non-root and no privilege escalation are valuable first
controls, but full hardening would also include seccomp, read-only root
filesystems, image signing, admission exceptions, runtime monitoring, and
periodic policy review.

## Q24: What did CCPU-204 add?

It added Kyverno validation fixtures: one valid Pod and invalid Pods for
missing resources, `latest` images, missing labels, and root/privilege
escalation. It also added a runbook and verifier so the policy behavior can be
explained and tested.

## Q25: Why are fixtures important for policy work?

Policies are easy to overclaim. Fixtures show the actual boundary: what should
pass and what should fail. That makes the policy easier to review, demo, and
debug during an interview or incident.

## Q26: What live commands prove Kyverno policy behavior?

Use `kubectl get cpol` to confirm `ClusterPolicy` resources exist. Use
`kubectl get policyreport -A` to inspect policy evaluation results. Then apply
the valid fixture and invalid fixtures to demonstrate allowed and denied
admission paths.

## Q27: What did CCPU-205 add?

It added OpenCost as a GitOps-managed platform add-on. The `opencost-dev` Argo
CD Application pins the OpenCost Helm chart to `2.5.23`, reads values from
`k8s/addons/opencost/values.yaml`, and deploys into the `opencost` namespace.

## Q28: Why is OpenCost part of platform operations?

Cost is an operational signal, like availability or latency. Once the platform
has namespaces for CPEmon, Kafka, monitoring, Argo CD, Kyverno, and OpenCost,
operators need visibility into where spend is coming from. This story starts
with visibility before chargeback or optimization.

## Q29: What did CCPU-206 add?

It configured OpenCost to use the existing kube-prometheus-stack Prometheus
service:
`http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090`.
The configuration lives in `k8s/addons/opencost/values.yaml`.

## Q30: Why does OpenCost need Prometheus?

OpenCost needs usage metrics before it can calculate cost allocation. Prometheus
stores the CPU, memory, pod, namespace, and workload time-series data. OpenCost
queries those metrics and turns them into cost views.

## Q31: Why reuse kube-prometheus-stack instead of deploying another
Prometheus?

One platform Prometheus is easier to operate and explain. If OpenCost used a
separate Prometheus, the team would have duplicate metrics storage and unclear
ownership. Reusing kube-prometheus-stack keeps monitoring and cost visibility
on the same source of truth.

## Q32: What is the required sync order?

Sync `monitoring-dev` first, then `opencost-dev`. OpenCost depends on the
Prometheus API, so cost visibility should come after the monitoring stack is
healthy.

## Q33: What did CCPU-207 add?

It documented namespace-level cost visibility with OpenCost. The runbook covers
`cpemon`, `kafka`, `monitoring`, `argocd`, `kyverno`, and `opencost`, and shows
how to query OpenCost allocation data by namespace.

## Q34: Why start with namespace-level cost?

Namespaces match the ownership boundaries in this platform. They let an
operator separate application cost from Kafka, monitoring, GitOps, governance,
and cost-visibility overhead. It is the clearest first FinOps view.

## Q35: Why say visibility is not chargeback?

Chargeback needs pricing accuracy, ownership labels, business rules, review
cadence, and finance alignment. This story only proves that the platform can
surface cost signals. It avoids pretending the organization is already doing
production cost allocation.

## Q36: What did CCPU-208 add?

It added an OpenCost access and cost investigation runbook. The main drill is a
Kafka namespace cost increase: start with namespace allocation, drill into
controller allocation, inspect Kafka pods/PVCs/resources, then correlate the
result with Argo CD history and Git changes.

## Q37: How does cost visibility become operationally useful?

Cost visibility is useful when it leads to an action. The runbook connects
OpenCost output to Kubernetes facts like replicas, requests, PVCs, failed pods,
and recent chart changes. That lets an operator decide whether the cost
increase is expected, accidental, or a follow-up optimization task.

## Q38: What would you record during a cost incident?

Record the OpenCost query window, the namespace and workload driving cost, the
Argo CD revision, resource changes, whether the increase was expected, and the
follow-up owner.

## Q39: What did CCPU-209 add?

It added a Helm-rendered `HorizontalPodAutoscaler` for `cpemon-api`. The chart
now has an `autoscaling` values block with `enabled`, `minReplicas`,
`maxReplicas`, and `targetCPUUtilizationPercentage`.

## Q40: Why is HPA disabled in base values but enabled in dev values?

The base chart should be conservative and environment-neutral. Enabling HPA in
dev values gives the team a visible rendered manifest for review and validation
without forcing every future environment to autoscale automatically.

## Q41: Why does the HPA target Rollout when canary deployment is enabled?

When Argo Rollouts is enabled, the Rollout object owns the desired replica
state. The HPA must scale the object that controls the pods, so the template
uses `argoproj.io/v1alpha1` and `kind: Rollout` in that mode. When rollout is
disabled, it targets the normal `apps/v1` Deployment.

## Q42: What dependencies does CPU-based HPA need?

It needs metrics-server and CPU requests on the containers. Metrics-server
provides the CPU utilization data, and requests give Kubernetes the baseline
needed to calculate utilization percentage.

## Q43: What did CCPU-210 add?

It added a runbook for validating the `cpemon-api` HPA in a dev cluster,
including metrics-server checks, `kubectl get hpa`, `kubectl describe hpa`, a
dev-only load-test path, cleanup, troubleshooting, and rollback.

## Q44: What does an HPA load test prove and not prove?

It proves the HPA object is wired correctly, can read metrics, and targets the
right workload. It does not prove production capacity, final SLO tuning, or
cost optimization because those need real traffic and historical metrics.

## Q45: Why mention `<unknown>` CPU targets?

`<unknown>` is the classic HPA symptom when metrics are unavailable. It usually
means metrics-server is unhealthy, `kubectl top` is not returning data, or the
containers do not have CPU requests.

## Q46: How do you roll back this HPA path?

Set `workloads.cpemonApi.autoscaling.enabled=false` for the environment and
sync the Helm release again. The workload then returns to the fixed
`replicaCount` behavior.
