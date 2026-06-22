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
