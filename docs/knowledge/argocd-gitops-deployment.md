# Argo CD GitOps Deployment

Story 11 introduces Argo CD as the GitOps controller for CPEmon.

## Why Argo CD

Before this story, the upgrade has infrastructure and packaging pieces:

```text
Terraform -> EKS and AWS foundation
Helm      -> CPEmon application templates
kubectl   -> manual apply and validation
```

Argo CD adds the deployment control plane:

```text
Git desired state -> Argo CD -> Kubernetes cluster
```

This is the CI/CD separation:

* CI builds, tests, and publishes images.
* Git records the desired deployment state.
* Argo CD reconciles the cluster to that desired state.

## CCPU-96: Install Argo CD

The first subtask establishes the Argo CD control plane in the `argocd`
namespace.

Learning install:

```powershell
kubectl apply -f k8s/addons/argocd/namespace.yaml
kubectl apply -n argocd --server-side --force-conflicts `
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Why this is acceptable for Step 1:

* It follows the official quick-start shape.
* It gets the GitOps controller running quickly.
* It avoids mixing controller installation with CPEmon Application design.
* The production hardening path is documented separately.

Production difference:

For production, pin the Argo CD version, review manifests, configure SSO/RBAC,
secure ingress/TLS, and define an upgrade/backup plan.

## Verification

```powershell
kubectl get ns argocd
kubectl get pods -n argocd
kubectl get deploy -n argocd
kubectl get svc -n argocd
```

For local UI access:

```powershell
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

## Interview Framing

Do not say "Argo CD builds and deploys my app." A stronger answer is:

> GitHub Actions owns CI: tests, builds, and image publishing. Git owns desired
> state. Argo CD owns CD: it watches Git, compares desired state with live
> cluster state, and reconciles drift.

## CCPU-97: Create Argo CD Project

The `cpemon` AppProject defines the first GitOps guardrail.

Manifest:

```text
k8s/addons/argocd/projects/cpemon-project.yaml
```

It allows Argo CD Applications in the `cpemon` project to read from the source
repository:

```text
https://github.com/huangruidtu/cpemon-mvp.git
```

It allows deployment to the learning target namespaces:

* `cpemon`
* `kafka`
* `monitoring`
* `security`
* `platform`

Why this matters:

An AppProject is a security and ownership boundary. It prevents the story from
accidentally teaching "Argo CD can deploy anything anywhere." Instead, the
project records which repository and target namespaces are allowed.

Production hardening:

The learning project is intentionally broad. A production platform should split
projects by environment or team, restrict cluster-scoped resources, and pair
the project with Argo CD RBAC.

## CCPU-175: Define GitOps Repository Layout

The repository now separates bootstrap resources from Application manifests.

Bootstrap resources:

```text
k8s/addons/argocd/
```

These install or prepare Argo CD itself, such as the namespace and AppProject.

Application manifests:

```text
k8s/gitops/dev/applications/
```

These are the Argo CD `Application` objects that tell Argo CD what to
reconcile.

The story starts with plain Application manifests instead of app-of-apps.

Why:

* one learning environment is easier to reason about directly
* individual Applications are easier to inspect and debug
* app-of-apps can be added later when multi-environment promotion or many apps
  make a root Application useful

Interview framing:

> GitOps layout is architecture. It tells the team which files bootstrap Argo
> CD, which files Argo CD reconciles, and how Helm chart paths map to deployed
> applications.

## CCPU-98: Create Application for CPEmon Helm Chart

The first workload Application is:

```text
k8s/gitops/dev/applications/cpemon-dev.yaml
```

It tells Argo CD:

* use the `cpemon` AppProject
* read from `https://github.com/huangruidtu/cpemon-mvp.git`
* follow the configured Git revision, currently `HEAD`
* render `deploy/helm/cpemon`
* apply the Helm values file `values-dev.yaml`
* deploy into the in-cluster Kubernetes API and `cpemon` namespace

The Application intentionally does not own image building. CI owns image build,
test, and push. Git owns the desired image tag. Argo CD owns reconciliation of
that desired state into the cluster.

The dev values file still contains `__IMAGE_TAG__` as a learning placeholder.
For a live sync, CI should promote a concrete tag into Git, or the lab operator
should replace the placeholder before applying the Application.

Manual sync is used at this point. Automated sync, prune, and self-heal are
separate operational choices and are handled later in the story.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-cpemon-application.ps1
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

Live Argo CD inspection:

```powershell
kubectl get application cpemon-dev -n argocd
kubectl describe application cpemon-dev -n argocd
argocd app get cpemon-dev
```

## CCPU-99: Create Application for Kafka

The Kafka Application is:

```text
k8s/gitops/dev/applications/kafka-dev.yaml
```

It tells Argo CD:

* use the `cpemon` AppProject
* render the Bitnami Kafka Helm chart from `registry-1.docker.io/bitnamicharts`
* pin the chart version to `32.4.3`
* pull values from this repository at `k8s/addons/kafka/values.yaml`
* deploy the release as `kafka` into the `kafka` namespace

The AppProject now allows both the CPEmon Git repository and the Bitnami chart
repository. This is intentional: Argo CD must be allowed to read every source
referenced by Applications in that project.

`kafka-dev` uses Argo CD multiple sources because the chart is external and the
values file is local to the CPEmon Git repository.

Sequencing:

```text
Argo CD control plane
        |
        v
cpemon AppProject
        |
        v
kafka-dev Application
        |
        v
cpemon-dev Application can use Kafka bootstrap config
```

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-kafka-application.ps1
helm template kafka oci://registry-1.docker.io/bitnamicharts/kafka `
  --namespace kafka `
  --version 32.4.3 `
  --values k8s/addons/kafka/values.yaml
```

Live Argo CD inspection:

```powershell
kubectl get application kafka-dev -n argocd
kubectl describe application kafka-dev -n argocd
argocd app get kafka-dev
```

## CCPU-100: Create Application for Monitoring Stack

The monitoring Application is:

```text
k8s/gitops/dev/applications/monitoring-dev.yaml
```

It tells Argo CD:

* use the `cpemon` AppProject
* render kube-prometheus-stack from `ghcr.io/prometheus-community/charts`
* pin the chart version to `86.3.2`
* use release name `kps`
* pull values from `k8s/monitoring/kube-prometheus-stack-values.yaml`
* deploy into the `monitoring` namespace

The AppProject now allows the Prometheus Community chart repository because
Argo CD must be allowed to read every source referenced by the Application.

Monitoring is treated as a platform add-on. It installs shared observability
control-plane components and CRDs such as `ServiceMonitor` and
`PrometheusRule`. CPEmon workloads can expose metrics and optional monitoring
resources, but they should not own the monitoring stack itself.

CRD ordering:

```text
monitoring-dev syncs kube-prometheus-stack
        |
        v
Prometheus Operator CRDs exist
        |
        v
CPEmon ServiceMonitor, PrometheusRule, and dashboards can be applied
```

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-monitoring-application.ps1
helm template kps oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack `
  --namespace monitoring `
  --version 86.3.2 `
  --values k8s/monitoring/kube-prometheus-stack-values.yaml
```

Live Argo CD inspection:

```powershell
kubectl get application monitoring-dev -n argocd
kubectl describe application monitoring-dev -n argocd
argocd app get monitoring-dev
```
