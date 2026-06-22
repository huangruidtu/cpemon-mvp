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

## CCPU-176: Create Application Boundary for External Secrets

The External Secrets Application is:

```text
k8s/gitops/dev/applications/external-secrets-dev.yaml
```

It tells Argo CD:

* use the `cpemon` AppProject
* render the `external-secrets` Helm chart from
  `https://charts.external-secrets.io`
* pin the chart version to `2.6.0`
* use release name `external-secrets`
* pull values from `k8s/addons/external-secrets/values.yaml`
* deploy into the `external-secrets` namespace

The values file enables CRD installation and keeps service account annotations
empty because the real IRSA role ARN is environment-specific.

GitOps secret boundary:

```text
Git:    controller config, SecretStore/ExternalSecret contracts, names, keys
AWS:    real secret values in Secrets Manager, encrypted with KMS
IRSA:   scoped AWS access for the ESO service account
ESO:    reconciles Kubernetes Secrets
Pods:   consume Kubernetes Secrets through secretKeyRef
```

The AppProject also now allows the cluster-scoped resources required by
operator charts, including ClusterRoles, ClusterRoleBindings, CRDs, webhook
configurations, and APIService objects. Without this, Argo CD could render an
operator chart but reject its cluster-scoped resources during sync.

Sync ordering:

```text
external-secrets-dev
        |
        v
ESO CRDs and controller ready
        |
        v
cpemon-dev with externalSecrets.enabled=true
        |
        v
Kubernetes Secrets reconciled from AWS Secrets Manager
```

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-external-secrets-application.ps1
helm template external-secrets external-secrets/external-secrets `
  --namespace external-secrets `
  --version 2.6.0 `
  --values k8s/addons/external-secrets/values.yaml
```

Live Argo CD inspection:

```powershell
kubectl get application external-secrets-dev -n argocd
kubectl describe application external-secrets-dev -n argocd
argocd app get external-secrets-dev
```

## CCPU-177: Create Application Boundary for Policy and Security Add-ons

The policy/security Application is:

```text
k8s/gitops/dev/applications/policy-security-dev.yaml
```

It tells Argo CD:

* use the `cpemon` AppProject
* read policy manifests from `k8s/netpol/baseline`
* deploy the staged NetworkPolicy baseline into the `cpemon` namespace
* keep sync manual until NetworkPolicy enforcement and labels are validated

Included now:

```text
k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml
```

Deferred:

* Kyverno controller
* Kyverno policy resources
* OPA Gatekeeper
* broad default-deny across platform namespaces

Reason:

NetworkPolicy baseline manifests already exist and have a documented dry-run
and troubleshooting boundary. Kyverno is still only a roadmap item in this
repository; it does not yet have chart values, a policy package, a runbook, or
a validation script.

Important boundary:

`Synced` means Argo CD applied the NetworkPolicy objects. It does not prove
network enforcement. Enforcement depends on the EKS CNI or another
policy-capable networking layer.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-policy-security-application.ps1
kubectl apply --dry-run=client --validate=false `
  -f k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml
```

The repository script is the offline validation boundary. The kubectl dry-run
is useful when kubeconfig points to a reachable API server; even client dry-run
can perform API discovery.

Live Argo CD inspection:

```powershell
kubectl get application policy-security-dev -n argocd
kubectl describe application policy-security-dev -n argocd
argocd app get policy-security-dev
```

## CCPU-101: Configure Sync Policy

Story 11 uses manual sync for the current dev GitOps boundary.

The decision is recorded in every dev Application:

```yaml
annotations:
  cpemon.io/sync-policy: manual
  cpemon.io/sync-prune: "disabled"
  cpemon.io/sync-self-heal: "disabled"
```

The Applications intentionally do not include:

```yaml
spec:
  syncPolicy:
    automated:
```

Why:

* CPEmon image tag promotion is still a deliberate Git handoff.
* Kafka and monitoring are stateful platform add-ons.
* External Secrets depends on CRDs, IRSA, AWS Secrets Manager, and KMS.
* NetworkPolicy needs real CNI enforcement and connectivity testing.

Manual sync is a safety boundary while the platform is being introduced. It
lets the operator inspect diff, order Applications, and verify health before
automation is added.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-sync-policy.ps1
```

Manual sync commands:

```powershell
argocd app sync cpemon-dev
argocd app sync kafka-dev
argocd app sync monitoring-dev
argocd app sync external-secrets-dev
argocd app sync policy-security-dev
```

## CCPU-178: Configure Self-Heal and Prune Guardrails

The current decision is:

```text
prune:     disabled
self-heal: disabled
```

This is not because the features are bad. It is because they are powerful.

Prune deletes resources that are no longer in Git. That needs special care for
stateful workloads, CRDs, shared namespaces, operator-owned resources, and
chart renames.

Self-heal reverts live drift back to Git. That is useful after Git ownership is
clear, but during learning or incident response it can undo a deliberate
temporary patch before the operator has finished debugging.

The guardrail runbook is:

```text
ops/runbooks/argocd-prune-self-heal-guardrails.md
```

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-prune-self-heal-guardrails.ps1
```

Interview framing:

> I did not enable prune and self-heal blindly. I kept them disabled while the
> project is still proving resource ownership, CRD ordering, stateful behavior,
> NetworkPolicy enforcement, and rollback procedures.

## CCPU-102: Test GitOps Deployment from Git

The validation runbook is:

```text
ops/runbooks/argocd-gitops-deployment-validation.md
```

The repository-level validation script is:

```text
scripts/verify-argocd-gitops-deployment-validation.ps1
```

This subtask validates the CPEmon GitOps deployment contract:

* `cpemon-dev` Application exists
* source repo is `https://github.com/huangruidtu/cpemon-mvp.git`
* revision is `HEAD`
* Helm chart path is `deploy/helm/cpemon`
* values file is `values-dev.yaml`
* destination namespace is `cpemon`
* local Helm render succeeds

Live Argo CD validation requires a reachable cluster API and Argo CD CRDs:

```powershell
kubectl get application cpemon-dev -n argocd
kubectl describe application cpemon-dev -n argocd
argocd app get cpemon-dev
argocd app diff cpemon-dev
argocd app sync cpemon-dev
```

What this proves:

```text
Git desired state -> Argo CD Application contract -> Helm render path
```

What it does not prove:

```text
CI image build, live secret sync, Kafka readiness, NetworkPolicy enforcement,
or external ingress behavior
```
