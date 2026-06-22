# Story 17: Argo CD GitOps Deployment

Use this page for Story 11 Jira work: Argo CD GitOps Deployment.

## Q1: Why introduce Argo CD?

Manual `kubectl apply` is useful for learning, but it does not give a durable
deployment source of truth. Argo CD makes Git the desired state, watches for
drift, and reconciles Kubernetes resources from the repository.

## Q2: Why install Argo CD after Helm?

Helm defines how the application renders into Kubernetes manifests. Argo CD
needs that packaging boundary so it can reconcile the chart from Git. The order
is easier to explain as:

```text
Terraform creates infrastructure.
Helm packages Kubernetes workloads.
Argo CD reconciles packaged workloads from Git.
```

## Q3: What did CCPU-96 add?

It added the Argo CD installation boundary: the `argocd` namespace manifest,
the learning install command, verification commands, access instructions, and a
runbook that explains what is learning-only versus production-ready.

## Q4: Does Argo CD replace GitHub Actions?

No. GitHub Actions remains CI: test, build, and publish images. Argo CD is CD:
it deploys the desired Kubernetes state from Git.

## Q5: Why is the `stable` upstream install acceptable here?

It is acceptable for the learning environment because it follows the official
quick-start path and keeps the first subtask small. For production, I would pin
an Argo CD version and review the manifests before rollout.

## Q6: What is the first validation after install?

Check the namespace and control-plane pods:

```powershell
kubectl get ns argocd
kubectl get pods -n argocd
kubectl get deploy -n argocd
kubectl get svc -n argocd
```

## Q7: What is the interview-level value of Argo CD?

The value is not just deployment automation. The value is a reviewable desired
state, drift detection, reconciliation, easier rollback, and a clean separation
between image build and cluster deployment.

## Q8: What is an AppProject?

An AppProject is an Argo CD guardrail. It defines which repositories an
Application can read from and which cluster destinations it can deploy to.

## Q9: Why not let every Application deploy anywhere?

That would make the GitOps controller too powerful by default. A project
boundary limits blast radius and makes ownership clearer. In CPEmon, the
learning project allows the repo to deploy only to the namespaces used by the
application and platform add-ons.

## Q10: What did CCPU-97 add?

It added the `cpemon` AppProject manifest, a project runbook, repository and
namespace boundary documentation, and validation that the project remains tied
to the CPEmon source repository.

## Q11: How would you harden the AppProject for production?

I would split projects by environment, restrict cluster-scoped resources,
review allowed repositories, add Argo CD RBAC, and avoid giving a single
learning project broad access to every namespace.

## Q12: Why define a GitOps layout before writing Applications?

Because every Application needs a clear source path, destination, and ownership
boundary. Defining the layout first prevents each Application from inventing a
different convention.

## Q13: What is the boundary between bootstrap and applications?

Bootstrap resources prepare Argo CD itself, such as the namespace and
AppProject. Application manifests are the desired-state objects Argo CD
reconciles after the control plane exists.

## Q14: Why not start with app-of-apps?

The project has one learning environment and a small number of Applications.
Plain Application manifests are easier to inspect and explain. App-of-apps is a
good future option when there are many Applications or multiple environments.

## Q15: What did CCPU-175 add?

It added the GitOps directory layout, dev Application directory, layout runbook,
validation script, and interview explanation for why repository paths are part
of deployment architecture.

## Q16: What did CCPU-98 add?

It added the first Argo CD workload Application: `cpemon-dev`. The Application
points Argo CD at the CPEmon Helm chart path, uses `values-dev.yaml`, belongs
to the `cpemon` AppProject, and targets the `cpemon` namespace.

## Q17: What is the difference between `Synced` and `Healthy`?

`Synced` means the live cluster matches the desired Git state for the
Application. `Healthy` means the resulting Kubernetes resources are actually
running well. An app can be synced but not healthy if the manifests were
applied but Pods, Services, Secrets, or dependencies are not ready.

## Q18: Why does CI still matter after adding Argo CD?

Argo CD does not build the CPEmon containers. CI still runs tests and publishes
images. The GitOps handoff happens when a concrete image tag is recorded in
Git, and Argo CD reconciles that desired tag into Kubernetes.

## Q19: Why keep automated sync out of the first Application?

Manual sync makes the first Application easier to inspect during learning. It
lets the team verify repository path, chart rendering, destination namespace,
and project permissions before deciding whether automated prune and self-heal
are appropriate.

## Q20: What would you check if `cpemon-dev` is `OutOfSync` or `Degraded`?

For `OutOfSync`, compare Git desired state with live resources and check
whether the configured revision is correct. For `Degraded`, inspect workload
Pods, required Secrets, database access, Kafka readiness, and optional CRDs
such as `ServiceMonitor`.

## Q21: What did CCPU-99 add?

It added `kafka-dev`, an Argo CD Application for the Kafka platform. It points
to the Bitnami Kafka Helm chart, pins chart version `32.4.3`, pulls CPEmon
Kafka values from Git, and deploys into the `kafka` namespace.

## Q22: Why does `kafka-dev` use multiple sources?

The chart and values live in different places. The Kafka chart comes from the
Bitnami OCI Helm repository, while the environment-specific values live in the
CPEmon Git repository. Argo CD multiple sources lets one Application combine
those inputs into one rendered desired state.

## Q23: Why update the AppProject for Kafka?

An AppProject limits which sources Applications can read. Because `kafka-dev`
reads from the Bitnami chart repository and the CPEmon Git repository, both
must be explicitly allowed by the project.

## Q24: Why should Kafka sync before CPEmon Kafka workloads?

Kafka is a platform dependency. CPEmon producers and consumers can be rendered
from Git, but runtime event flow depends on a ready broker, bootstrap service,
topics, and persistent storage. Syncing Kafka first reduces noisy application
failures.

## Q25: What would you check if Kafka is synced but not healthy?

Inspect the `kafka-controller` StatefulSet, Pod events, PVC binding, node
capacity, StorageClass behavior, and bootstrap Service. For Kafka, `Synced`
only proves Argo CD applied desired manifests; `Healthy` depends on stateful
runtime readiness.

## Q26: What did CCPU-100 add?

It added `monitoring-dev`, an Argo CD Application for kube-prometheus-stack.
It pins chart version `86.3.2`, uses release name `kps`, reads CPEmon values
from Git, and deploys the monitoring stack into the `monitoring` namespace.

## Q27: Why is monitoring a platform add-on?

Monitoring is shared infrastructure. It owns Prometheus, Grafana, Alertmanager,
Prometheus Operator CRDs, scrape discovery, and alert evaluation. Application
teams expose metrics, but the platform owns the observability control plane.

## Q28: Why do ServiceMonitor and PrometheusRule need ordering?

They are not built-in Kubernetes resources. They are CRDs installed by the
Prometheus Operator/kube-prometheus-stack. If CPEmon-specific ServiceMonitors
or PrometheusRules are applied before those CRDs exist, Kubernetes rejects the
objects.

## Q29: What does `Synced` versus `Healthy` mean for monitoring?

`Synced` means Argo CD applied the desired chart output. `Healthy` means the
operator, Prometheus, Grafana, Alertmanager, webhooks, and required storage are
actually ready.

## Q30: What would you check if monitoring is degraded?

Check the Prometheus Operator Deployment, Prometheus StatefulSet, Grafana
Deployment, Alertmanager, admission webhook jobs, CRDs, PVCs, and events in the
`monitoring` namespace.

## Q31: What did CCPU-176 add?

It added `external-secrets-dev`, an Argo CD Application for External Secrets
Operator. It pins chart version `2.6.0`, uses release name `external-secrets`,
reads controller values from Git, and deploys into the `external-secrets`
namespace.

## Q32: Why does GitOps not mean committing secrets?

GitOps means Git owns desired state. For secrets, the desired state is the
contract: SecretStore, ExternalSecret, target Secret names, keys, and workload
references. The secret values themselves stay in AWS Secrets Manager and are
protected by KMS.

## Q33: Why does ESO need IRSA?

ESO needs AWS API permissions to read approved Secrets Manager values. IRSA
lets the `external-secrets/external-secrets` service account assume a scoped
IAM role without storing AWS access keys in Kubernetes.

## Q34: Why update the AppProject cluster resource allowlist?

Operator charts create cluster-scoped resources such as CRDs, ClusterRoles,
ClusterRoleBindings, and webhook configurations. If the AppProject does not
allow them, Argo CD can render the chart but reject the sync.

## Q35: What is the sync order for ESO and CPEmon secrets?

Sync ESO first so CRDs and the controller exist. Then sync CPEmon chart
resources that render SecretStore and ExternalSecret objects. Finally verify
that Kubernetes Secrets are created and workloads consume them through
`secretKeyRef`.

## Q36: What did CCPU-177 add?

It added `policy-security-dev`, an Argo CD Application for the staged CPEmon
NetworkPolicy baseline. It points to `k8s/netpol/baseline` and targets the
`cpemon` namespace.

## Q37: Why defer Kyverno?

Kyverno is a real future policy-controller option, but this repository does
not yet have a pinned Kyverno chart, values file, policy package, controller
runbook, or validation script. Adding it now would create more moving parts
than proof.

## Q38: How are platform guardrails different from app manifests?

App manifests deploy workload behavior. Guardrails constrain workload behavior,
such as network traffic, admission rules, image policy, or required labels.
They need gradual rollout, validation, and rollback guidance because a mistake
can break otherwise healthy applications.

## Q39: Does Argo CD `Synced` prove NetworkPolicy enforcement?

No. `Synced` means the NetworkPolicy objects were applied. Enforcement depends
on the CNI or policy engine. The real proof is connectivity testing: allowed
flows work and denied flows fail.

## Q40: Why start with CPEmon NetworkPolicy instead of broad default-deny?

The CPEmon app namespace has known dependencies such as DNS, MySQL, and
monitoring. Starting there makes the policy reviewable. Broad default-deny
across platform namespaces can break controllers before their traffic patterns
are mapped.

## Q41: What did CCPU-101 add?

It made the sync policy explicit across the dev Argo CD Applications. Each
Application records manual sync, prune disabled, and self-heal disabled through
metadata annotations, and the validation script checks that `automated:` is not
enabled.

## Q42: Is manual sync the same as not using GitOps?

No. Git still owns desired state and Argo CD still compares Git to the cluster.
Manual sync only means a human chooses when reconciliation is applied.

## Q43: Why not enable automated sync immediately?

The story still has stateful add-ons, operator CRDs, secrets, and NetworkPolicy
guardrails. Manual sync lets the operator inspect diffs and sequence changes
before automated reconciliation starts changing the cluster.

## Q44: Does Argo CD sync build images?

No. CI builds, tests, and publishes images. Argo CD sync applies desired
Kubernetes state from Git. If a new image should deploy, CI or a promotion step
must record the desired tag in Git first.

## Q45: When would automated sync be safer?

After image promotion is clear, health checks are stable, prune behavior is
tested, RBAC is hardened, and each platform Application has rollback and
troubleshooting guidance.

## Q46: What did CCPU-178 add?

It added a dedicated prune and self-heal guardrail runbook and validation
script. The decision is that prune and self-heal remain disabled for the
current dev Applications.

## Q47: Why does prune deserve special care?

Prune deletes live resources that are missing from Git. That can be correct,
but it can also delete stateful resources, CRDs, shared objects, or resources
renamed by a chart change if ownership is not clear.

## Q48: Why can self-heal be risky during incidents?

Self-heal reverts live drift automatically. If an operator temporarily patches
or scales a workload during debugging, self-heal may undo that action before
the incident is understood.

## Q49: When would you enable prune?

After Application ownership is clean, deletion behavior is tested in dev,
stateful resources are protected, and rollback or restore procedures are
documented.

## Q50: How do you validate this guardrail?

The validation script checks all dev Application manifests for prune/self-heal
disabled annotations and fails if it finds `prune: true` or `selfHeal: true`.

## Q51: What did CCPU-102 add?

It added a GitOps deployment validation runbook and script for `cpemon-dev`.
The script verifies the Application source repo, revision, chart path, values
file, destination namespace, manual sync policy, and local Helm rendering.

## Q52: What does this validation prove?

It proves the repository contains a reviewable Argo CD Application contract and
that the CPEmon Helm chart can render with the referenced dev values file.

## Q53: What does it not prove?

It does not prove live Argo CD sync, image availability, ESO secret sync, Kafka
readiness, NetworkPolicy enforcement, or ingress behavior. Those need a live
cluster and their own checks.

## Q54: Why is `argocd app get` useful?

It shows how Argo CD sees the Application: project, source, destination, sync
status, health status, conditions, and managed resources.

## Q55: How do you explain GitOps deployment in one sentence?

Git records desired deployment state, Argo CD compares that desired state with
the cluster, and sync reconciles the cluster toward Git.

## Q56: What did CCPU-179 add?

It added a drift detection validation runbook and documentation check. The
runbook uses a safe annotation drift on `deployment/cpemon-api`, observes
`OutOfSync`, then reconciles manually with `argocd app sync cpemon-dev`.

## Q57: Why use annotation drift instead of changing app behavior?

An annotation drift is visible to Argo CD but usually does not affect runtime
capacity or traffic. It is safer than changing replicas or container settings
for a first drift test.

## Q58: What status transition do you expect?

The expected transition is `Synced -> OutOfSync -> Synced` after manual sync.

## Q59: Does this prove self-heal?

No. Self-heal is disabled. This proves drift detection and manual
reconciliation. Automated self-heal would need a separate controlled test after
the guardrails are approved.

## Q60: Why is drift detection the GitOps value proposition?

It makes the cluster auditable against Git. Operators can see when live state
differs from reviewed desired state and choose whether to reconcile or update
Git.
