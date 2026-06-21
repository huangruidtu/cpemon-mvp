# Helm CPEmon Application

## Why This Story Exists

`CCPU-6` moves CPEmon from raw Kubernetes YAML toward a reusable Helm chart.

The previous stories prepared the layers below the application:

```text
CCPU-4: AWS and EKS infrastructure with Terraform
CCPU-5: Kubernetes platform add-ons
CCPU-6: CPEmon application packaging with Helm
```

This matters because a migration project is not only about starting a cluster. The application must also become repeatable, configurable, reviewable, and eventually GitOps-friendly.

## What Helm Is

Helm is a package manager and templating system for Kubernetes.

Instead of copying many environment-specific YAML files, a team defines:

- templates: reusable Kubernetes object patterns
- values: environment-specific inputs
- chart metadata: package identity and version
- release state: what Helm installed into a namespace

The mental model is:

```text
templates + values -> rendered Kubernetes YAML -> install or upgrade
```

For interview purposes, Helm is the bridge between plain Kubernetes manifests and repeatable application delivery.

## What CCPU-51 Adds

The first subtask creates the chart scaffold at:

```text
deploy/helm/cpemon
```

The scaffold includes:

| File | Purpose |
| --- | --- |
| `Chart.yaml` | Defines the chart name, type, chart version, app version, keywords, and maintainer metadata. |
| `values.yaml` | Defines default, environment-neutral configuration. |
| `values-dev.yaml` | Defines safe dev overrides, such as namespace and placeholder image tags. |
| `templates/_helpers.tpl` | Defines reusable template helpers for names, labels, and namespace selection. |
| `templates/NOTES.txt` | Prints human-readable guidance after render/install. |
| `.helmignore` | Excludes local-only files from packaged chart archives. |
| `README.md` | Documents how to render and reason about the chart. |

## Why Start With a Scaffold

It is tempting to immediately template every Deployment and Service.

For learning and migration safety, the chart is built in layers:

```text
scaffold -> values model -> workload templates -> optional platform features -> validation
```

This lets each step answer a clear question:

- What is a Helm chart?
- What should be configurable?
- Which parts of the old YAML become templates?
- Which parts should stay as secret references?
- How do we validate before applying anything?

## Chart.yaml Explained

`Chart.yaml` is chart metadata, not a Kubernetes resource.

Important fields:

- `apiVersion: v2` means Helm 3 chart format.
- `name: cpemon` is the chart package name.
- `type: application` means this chart deploys an application, not a reusable library chart.
- `version` is the chart version.
- `appVersion` is the application version metadata.

The important distinction:

```text
chart version changes when the chart changes
app version changes when the application release changes
image tag is controlled by values
```

## values.yaml Explained

`values.yaml` is the default input model for templates.

For CPEmon it captures:

- image registry and pull secret references
- global image tag and pull policy defaults
- common labels
- non-secret app config
- Secret names and key references
- workload names, components, replicas, ports, resources, probes, env, and secret env
- shared defaults for services, ports, probes, resources, pod labels, annotations, and env
- scheduling controls such as worker-node preference, node selectors, tolerations, and affinity overrides
- optional features such as ingress, NetworkPolicy, PDB, and ServiceMonitor

The values file should not contain real production secrets.

## CCPU-52: Values Model and Dev Overrides

The second subtask makes the values model detailed enough for future templates.

The important design choice is to separate shared defaults from workload-specific differences:

```text
global defaults -> shared chart defaults -> per-workload overrides -> environment values file -> CLI --set
```

This keeps the chart readable. It also prevents copy-paste drift between `cpemon-api`, `acs-ingest`, and `cpemon-writer`.

### Image Strategy

The chart uses a global image registry, global default tag, and global pull policy:

```yaml
global:
  imageRegistry: "701573843911.dkr.ecr.eu-north-1.amazonaws.com"
  imageTag: "dev"
  imagePullPolicy: IfNotPresent
```

Each workload defines its repository:

```yaml
workloads:
  cpemonApi:
    image:
      repository: cpemon-api
      tag: ""
      pullPolicy: ""
```

The empty string is intentional. It means "use the global default". A later template can resolve image values with this logic:

```text
repository = global.imageRegistry + "/" + workload.image.repository
tag = workload.image.tag or global.imageTag
pullPolicy = workload.image.pullPolicy or global.imagePullPolicy
```

This pattern is common because most workloads in one release use the same image tag from the same CI build, but the chart still allows exceptions.

### Workload Model

Each workload has:

- `enabled`
- `name`
- `component`
- `replicaCount`
- `image`
- `env`
- `secretEnv`

The workload names match the current raw manifests:

```text
cpemon-api
acs-ingest
cpemon-writer
```

The `component` field is for stable labels. For example, later templates can label pods with:

```yaml
app.kubernetes.io/component: api
```

That label is better than relying only on `app: cpemon-api`, because Kubernetes recommended labels make ownership and filtering clearer.

### Env vs Secret Env

The values model separates non-secret env from secret-backed env:

```yaml
env:
  - name: HTTP_ADDR
    value: ":8080"
secretEnv:
  - name: DB_DSN
    secretName: cpemon-db
    secretKey: dsn
```

This is a security boundary.

Non-secret values can be committed. Secret values are not committed; only the Kubernetes Secret name and key are committed.

### Defaults Section

The `defaults` section contains shared settings:

- service type and annotations
- HTTP and metrics ports
- liveness/readiness probe timing
- CPU/memory requests and limits
- pod annotations and labels
- shared env and envFrom hooks

This prevents repeating the same probe, service, port, and resource configuration three times.

### Dev Overrides

`values-dev.yaml` now stays deliberately small:

```yaml
global:
  namespaceOverride: cpemon
  imageTag: "__IMAGE_TAG__"
```

It also records dev Secret names and replica counts.

The principle is:

```text
values.yaml describes the chart's default model
values-dev.yaml describes only what is different for dev rendering
```

That is the core Helm values lesson.

### values.schema.json

The chart now includes:

```text
deploy/helm/cpemon/values.schema.json
```

Helm automatically uses this file during linting and rendering. It gives the values model a basic type contract.

Examples of mistakes it can catch:

- a replica count written as `"two"` instead of `2`
- an invalid image pull policy
- a workload missing its image repository
- a secret-backed env var missing `secretName` or `secretKey`

The schema is intentionally focused. It validates the stable parts of the values model while leaving room for later subtasks to add detailed rules for ingress, NetworkPolicy, PDB, and ServiceMonitor.

## CCPU-53: Template CP Model Application Workflows

`CCPU-53` is the point where the values model becomes real Kubernetes output.

The task adds:

```text
deploy/helm/cpemon/templates/workloads.yaml
```

and extends:

```text
deploy/helm/cpemon/templates/_helpers.tpl
```

The chart now renders the three CPEmon application workflows:

| Workload | Component | Kubernetes objects rendered |
| --- | --- | --- |
| `cpemon-api` | `api` | Deployment + Service |
| `acs-ingest` | `ingest` | Deployment + Service |
| `cpemon-writer` | `writer` | Deployment + Service |

The key migration idea is:

```text
old raw YAML objects -> shared Helm values model -> reusable workload template -> rendered Kubernetes YAML
```

### Why Template the Workloads Together

The three services have the same deployment shape:

- image registry, repository, tag, and pull policy
- replicas
- HTTP and metrics ports
- liveness and readiness probes
- CPU and memory resources
- image pull secret
- optional scheduling preferences
- ClusterIP Service

Only a few things differ:

- workload name
- component label
- image repository
- replica count
- environment variables
- secret-backed environment variables

This is exactly where Helm is useful. The repeated Kubernetes structure moves into the template. The workload-specific differences stay in `values.yaml`.

### Label and Selector Design

The templates keep the historical label:

```yaml
app: cpemon-api
```

This matters because existing monitoring and availability manifests already select workloads by the `app` label.

The templates also add recommended Kubernetes labels:

```yaml
app.kubernetes.io/name
app.kubernetes.io/instance
app.kubernetes.io/component
app.kubernetes.io/managed-by
```

This gives the chart a cleaner production-style ownership model without breaking existing selectors.

The selector helper is intentionally small:

```text
app + release instance + component
```

Deployment selectors are immutable after creation, so selector fields should be stable and not include labels that change frequently.

### Image Resolution

The workload image is resolved from:

```text
global.imageRegistry + workload.image.repository + workload image tag or global.imageTag
```

For example, `cpemon-api` renders as:

```text
701573843911.dkr.ecr.eu-north-1.amazonaws.com/cpemon-api:__IMAGE_TAG__
```

This preserves the current migration behavior while preparing for CI to pass a commit SHA or release tag later.

### Environment Variables and Secrets

Plain environment variables render as:

```yaml
env:
  - name: HTTP_ADDR
    value: ":8080"
```

Secret-backed environment variables render as:

```yaml
env:
  - name: DB_DSN
    valueFrom:
      secretKeyRef:
        name: cpemon-db
        key: dsn
```

This is a meaningful improvement over the older raw YAML, where sensitive database and HMAC values could appear directly in manifests.

The interview point is:

> The Helm chart stores secret references, not secret material.

### Scheduling Model

The template preserves the existing lab-friendly scheduling behavior:

- prefer nodes labeled `cpemon-role=worker`
- prefer spreading replicas across different nodes with pod anti-affinity
- optionally tolerate control-plane taints for compact demo clusters

This makes the chart compatible with the previous MVP behavior while keeping the scheduling model configurable from values.

### Validation Result

Because the local shell did not already have Helm installed, Helm was downloaded temporarily for validation.

The chart passed:

```powershell
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

`helm lint` returned one informational recommendation about adding a chart icon, and no chart failures.

## CCPU-54: Template Services, Config, and Secret References

`CCPU-54` sharpens the boundary between service exposure, non-secret configuration, and secret references.

The important implementation change is:

```text
deploy/helm/cpemon/templates/configmap.yaml
```

The chart now renders a ConfigMap named:

```text
cpemon-app-config
```

### What Goes Into the ConfigMap

The ConfigMap stores non-secret runtime configuration:

| ConfigMap key | Purpose |
| --- | --- |
| `HTTP_ADDR` | HTTP listen address used by the services. |
| `GRAFANA_HOME_URL` | Link target for the Grafana home page. |
| `GRAFANA_SN_DASHBOARD_URL_TEMPLATE` | Template used to build per-device Grafana links. |
| `KIBANA_HOME_URL` | Link target for the Kibana discover page. |
| `KIBANA_SN_LOGS_URL_TEMPLATE` | Template used to build per-device Kibana log links. |

These values are safe to commit because they are configuration, not credentials.

Workload env entries that use:

```yaml
valueFromConfig: grafanaHomeUrl
```

now render as:

```yaml
valueFrom:
  configMapKeyRef:
    name: cpemon-app-config
    key: GRAFANA_HOME_URL
```

This is better than scattering the same literal values across every Deployment.

### What Stays as Secret References

Sensitive values are not rendered into the chart.

The chart references these pre-existing Secrets:

| Env var | Secret | Key | Used by |
| --- | --- | --- | --- |
| `DB_DSN` | `cpemon-db` | `dsn` | `cpemon-api`, `acs-ingest`, `cpemon-writer` |
| `HMAC_SECRET` | `cpemon-acs-hmac` | `hmac-secret` | `acs-ingest` |

The chart also references the image pull Secret:

```text
cpemon-ecr-regcred
```

That Secret is used by Kubernetes to pull private ECR images.

### ConfigMap vs Secret vs Helm Values

A good mental model is:

```text
Helm values decide what should be rendered.
ConfigMaps hold non-sensitive runtime configuration.
Secrets hold sensitive runtime configuration.
External secret tooling decides how real secret material enters the cluster.
```

Helm values are not a safe place for production passwords because values can appear in Git, CI logs, rendered manifests, and Helm release history.

For this project, the chart owns:

- ConfigMap shape
- env var wiring
- Secret names and keys

The chart does not own:

- real DB passwords
- real HMAC secrets
- long-lived cloud credentials

### Service Boundary

The Service rendering from `CCPU-53` satisfies the service-facing part of `CCPU-54`.

Each enabled workload renders a ClusterIP Service with:

- `http` port `8080`
- `metrics` port `9100`
- selectors that match the Deployment pod labels

This keeps application traffic and metrics discovery stable while the configuration model becomes more production-like.

### Validation Result

The chart passed:

```powershell
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

The rendered output includes:

- one ConfigMap: `cpemon-app-config`
- three Services
- three Deployments
- `configMapKeyRef` for non-secret config
- `secretKeyRef` for sensitive runtime inputs

## CCPU-55: Optional Platform Feature Templates

`CCPU-55` adds optional platform integrations around the CPEmon application chart.

The new templates are:

```text
deploy/helm/cpemon/templates/ingress.yaml
deploy/helm/cpemon/templates/servicemonitor.yaml
deploy/helm/cpemon/templates/pdb.yaml
deploy/helm/cpemon/templates/networkpolicy.yaml
```

All four features are controlled by values flags and are disabled by default:

```yaml
ingress:
  enabled: false
serviceMonitor:
  enabled: false
pdb:
  enabled: false
networkPolicy:
  enabled: false
```

This is deliberate. Optional platform features often depend on cluster add-ons:

| Feature | Cluster dependency |
| --- | --- |
| Ingress | An ingress controller such as ingress-nginx or AWS Load Balancer Controller. |
| ServiceMonitor | Prometheus Operator CRDs from kube-prometheus-stack. |
| PDB | Kubernetes eviction behavior and enough replicas to keep available pods. |
| NetworkPolicy | A CNI or policy engine that enforces NetworkPolicy. |

The chart should be renderable in a plain dev workflow without requiring all of those platform integrations to exist.

### Ingress Template

The Ingress template routes external HTTP paths to internal Services:

| Path | Backend workload |
| --- | --- |
| `/acs/webhook` | `acs-ingest` |
| `/cpe` | `cpemon-api` |
| `/api` | `cpemon-api` |

The default host is:

```text
api.local
```

The Ingress is disabled by default because a cluster must already have a compatible ingress controller. The template preserves the old raw YAML behavior while making host, class, annotations, paths, backends, and ports configurable.

### ServiceMonitor Template

The ServiceMonitor template creates:

```text
cpemon-services
```

in the monitoring namespace by default.

It selects Services by the compatibility `app` label and scrapes the `metrics` port. This preserves the existing monitoring behavior while letting the chart control whether monitoring integration should be rendered.

The ServiceMonitor is disabled by default because `ServiceMonitor` is not a built-in Kubernetes resource. It only exists after Prometheus Operator CRDs are installed.

### PDB Template

The PDB template creates disruption budgets only for workloads enabled in:

```yaml
pdb:
  workloads:
    cpemonApi:
      enabled: true
    acsIngest:
      enabled: true
    cpemonWriter:
      enabled: false
```

`cpemon-writer` is disabled by default because it has one replica. A `minAvailable: 1` PDB on a single-replica workload can block voluntary disruptions and make maintenance harder.

### NetworkPolicy Template

The NetworkPolicy template renders a baseline posture when enabled:

- default deny egress for the namespace
- allow DNS egress to kube-dns
- allow core app egress to MySQL
- optionally allow egress to monitoring and logging namespaces

This is conservative and explicit. It teaches the important production point:

> A NetworkPolicy should be enabled only when the team understands the cluster's policy enforcement mode and required traffic paths.

### Validation Result

The chart passed default rendering with all optional features disabled:

```powershell
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

Default dev rendering produced no optional platform resources.

The optional templates were also rendered by explicitly enabling all four flags:

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml --set ingress.enabled=true --set serviceMonitor.enabled=true --set pdb.enabled=true --set networkPolicy.enabled=true
```

That rendered:

- 1 Ingress
- 1 ServiceMonitor
- 2 PodDisruptionBudgets
- 3 NetworkPolicies

## CCPU-56: Helm Validation Makefile Targets

`CCPU-56` turns the Helm validation commands into repeatable Makefile targets.

The targets are:

```text
helm-check
helm-cpemon-lint
helm-cpemon-template
helm-cpemon-validate
```

The Makefile variables are:

```makefile
HELM ?= helm
HELM_CPEMON_CHART ?= deploy/helm/cpemon
HELM_CPEMON_RELEASE ?= cpemon
HELM_CPEMON_NAMESPACE ?= cpemon
HELM_CPEMON_VALUES ?= deploy/helm/cpemon/values-dev.yaml
HELM_CPEMON_RENDER_OUT ?= build/helm/cpemon-rendered.yaml
```

This means the default validation path is:

```powershell
make helm-cpemon-validate
```

That runs:

```text
helm lint
helm template
```

against the CPEmon chart and dev values file.

If `helm` is installed but not visible in the current shell's `PATH`, the binary can be passed explicitly:

```powershell
make helm-cpemon-validate HELM="C:/path/to/helm.exe"
```

### Why Add Makefile Targets

Raw commands are easy to mistype:

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

A Makefile target gives the team one stable entry point.

That matters in real teams because the same validation should run:

- on a developer laptop
- in CI
- before a PR review
- before GitOps consumes the chart

### What Each Target Does

`helm-check` confirms Helm can run and prints a clear error if it cannot.

`helm-cpemon-lint` checks chart structure, values schema, and common template problems.

`helm-cpemon-template` renders the chart locally into:

```text
build/helm/cpemon-rendered.yaml
```

`helm-cpemon-validate` runs lint and template together.

### Why Not Install Yet

`helm template` and `helm lint` are pre-apply checks.

They do not need a live cluster and do not create resources.

Live install is still deferred because the EKS cluster and required runtime Secrets must exist first:

```powershell
helm upgrade --install cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

That command belongs to a later live deployment or GitOps story.

## CCPU-57: Chart Usage and Migration Decisions

`CCPU-57` turns the Helm chart work into operator-facing documentation.

The main new artifact is:

```text
ops/runbooks/helm-cpemon-application.md
```

The runbook explains:

- required local tools
- chart inputs
- required pre-existing Secrets
- local validation
- rendered output review
- optional platform feature rendering
- future live install
- future post-install checks
- upgrade and rollback workflow
- troubleshooting
- migration decision summary

### Why a Runbook Matters

A chart README explains the chart.

A runbook explains the workflow.

That distinction matters in production-style platform work. Operators and reviewers need to know not only what files exist, but also:

- what to run first
- what output to inspect
- what not to run yet
- what prerequisites must exist
- how to recover if a release fails

### Helm as Application Packaging

The migration decision is not "Helm replaces everything."

The boundary is:

```text
Terraform -> cloud infrastructure
Kubernetes add-ons -> platform capabilities
Helm -> application package
Argo CD -> future GitOps reconciliation
```

Helm owns the CPEmon application rendering layer:

- Deployments
- Services
- ConfigMap
- Secret references
- optional Ingress
- optional ServiceMonitor
- optional PDB
- optional NetworkPolicy

Helm does not own:

- VPCs
- EKS clusters
- IAM roles
- ECR repositories
- production secret material
- GitOps reconciliation

### Raw YAML to Helm

The raw YAML was useful for the MVP because it made every Kubernetes object explicit.

The Helm chart is useful for the upgrade because it makes variation explicit:

```text
stable Kubernetes object shape + environment-specific values = rendered manifests
```

This is the key interview point:

> I did not move to Helm because raw YAML is wrong. I moved to Helm because the application had reached the point where repeated manifests, image tags, environment-specific settings, and optional platform integrations needed a reusable packaging model.

### Pre-Apply vs Post-Apply

Current pre-apply work:

- lint the chart
- render the chart
- inspect generated manifests
- validate values schema
- document required Secrets and cluster dependencies

Future post-apply work:

- install or upgrade the Helm release
- check `helm status`
- check Deployment rollouts
- check Services and endpoints
- check optional Ingress, ServiceMonitor, PDB, and NetworkPolicy resources
- test application health endpoints

Keeping those phases separate prevents the project from claiming live deployment validation before the EKS cluster exists.

## Helm Values Precedence

When Helm renders a chart, values are merged from several sources.

Common precedence from lower to higher is:

```text
chart values.yaml
additional -f values file
later -f values file
--set / --set-string / --set-file
```

For this project:

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

means:

```text
start with values.yaml
merge values-dev.yaml on top
render templates
```

If CI later passes:

```powershell
--set global.imageTag=sha-abc123
```

that CLI value overrides both files.

## values-dev.yaml Explained

`values-dev.yaml` is an environment override.

It currently sets:

```yaml
global:
  namespaceOverride: cpemon
  imageTag: "__IMAGE_TAG__"
```

and uses `__IMAGE_TAG__` placeholders so the migration remains compatible with the existing raw YAML workflow.

In a real CI/CD pipeline, the image tag would usually be passed with:

```powershell
helm upgrade --install cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml --set workloads.cpemonApi.image.tag=<tag>
```

## _helpers.tpl Explained

`_helpers.tpl` stores reusable template functions.

This avoids repeating label and naming logic in every template. That matters because Kubernetes selectors are sensitive: if a Deployment selector and Service selector drift apart, traffic breaks.

Helpers added in the scaffold:

- `cpemon.name`
- `cpemon.fullname`
- `cpemon.labels`
- `cpemon.namespace`

## Pre-Apply Boundary

Current state:

```text
The chart exists and can be rendered locally.
Helm is installed, although some existing shells may need PATH refresh.
The EKS cluster has not been applied.
No Helm release has been installed.
```

So the safe validation goal is local lint/render:

```powershell
make helm-cpemon-validate
```

These commands do not create cluster resources. They only validate and render manifests locally.

## Interview Framing

A strong explanation is:

> We first migrated infrastructure to Terraform, then prepared EKS platform add-ons, then started packaging CPEmon workloads with Helm. The first Helm task intentionally creates the chart scaffold and values model before templating workloads, so later changes are reviewable and environment-specific configuration is separated from reusable Kubernetes object structure.
