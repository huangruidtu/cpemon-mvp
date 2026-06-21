# CPEmon Helm Chart

This chart packages the CPEmon application workloads for the cloud platform upgrade.

It is the application layer that sits above the EKS infrastructure and platform add-ons:

```text
Terraform AWS/EKS foundation -> Kubernetes platform add-ons -> CPEmon Helm chart
```

## Current Scope

`CCPU-51` creates the chart scaffold:

- `Chart.yaml` defines the chart identity and version.
- `values.yaml` defines the default configuration model.
- `values-dev.yaml` provides safe dev overrides.
- `templates/_helpers.tpl` centralizes names, labels, and namespace logic.
- `templates/NOTES.txt` gives install-time guidance.

`CCPU-52` expands the values model so the chart has a clear contract before templates are added.

`CCPU-53` templates the three CPEmon application workflows:

- `cpemon-api`
- `acs-ingest`
- `cpemon-writer`

Each enabled workload now renders a Kubernetes Deployment and Service from the shared values model.

## Render Commands

When Helm is installed:

```powershell
helm lint deploy/helm/cpemon
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

These commands render locally. They do not create AWS or Kubernetes resources.

The repository also provides repeatable Makefile targets:

```powershell
make helm-cpemon-lint
make helm-cpemon-template
make helm-cpemon-validate
```

If `helm` is installed but not on the current shell `PATH`, pass the binary explicitly:

```powershell
make helm-cpemon-validate HELM="C:/path/to/helm.exe"
```

The render target writes:

```text
build/helm/cpemon-rendered.yaml
```

Live `helm upgrade --install` is intentionally deferred until the target EKS cluster and required Secrets exist.

## Secrets Boundary

Do not commit production database passwords, HMAC secrets, or image pull credentials into this chart.

This chart should reference Kubernetes Secrets by name and key. The actual Secret objects can come from manual bootstrap, External Secrets Operator, Sealed Secrets, SOPS, or another secret-management story.

## Chart Version vs App Version

`version` in `Chart.yaml` is the Helm package version. Change it when the chart itself changes.

`appVersion` describes the application version being packaged. It is documentation metadata and does not automatically change image tags.

Image tags are controlled through values:

```yaml
global:
  imageTag: "dev"
```

Workload-specific image tags may still override the global tag when needed:

```yaml
workloads:
  cpemonApi:
    image:
      tag: "api-specific-tag"
```

## Values Model

The chart values are grouped by responsibility:

| Section | Purpose |
| --- | --- |
| `global` | Namespace override, registry, default tag, pull policy, image pull secrets, and shared labels. |
| `appConfig` | Non-secret runtime configuration rendered through the chart ConfigMap. |
| `database` | Database endpoint metadata and the Secret reference used for `DB_DSN`. |
| `secretRefs` | Named Secret references for sensitive inputs that must not be committed as raw values. |
| `defaults` | Shared service, port, probe, resource, annotation, and env defaults. |
| `workloads` | Per-service configuration for `cpemon-api`, `acs-ingest`, and `cpemon-writer`. |
| `podScheduling` | Node affinity, toleration, node selector, and scheduling override model. |
| `ingress`, `networkPolicy`, `pdb`, `serviceMonitor` | Optional platform features added in later subtasks. |
| `values.schema.json` | JSON Schema used by Helm to validate common values mistakes during lint/render. |

The model uses a global image tag by default:

```yaml
global:
  imageRegistry: "701573843911.dkr.ecr.eu-north-1.amazonaws.com"
  imageTag: "dev"
```

Each workload can override the repository, tag, or pull policy:

```yaml
workloads:
  cpemonApi:
    image:
      repository: cpemon-api
      tag: ""
      pullPolicy: ""
```

An empty workload image tag means "use `global.imageTag`". An empty workload pull policy means "use `global.imagePullPolicy`".

## Dev Overrides

`values-dev.yaml` should stay small. It should only describe what is different in the dev/EKS environment:

- namespace override
- dev image tag placeholder
- dev Secret names and keys
- dev replica counts

This keeps the default chart model readable while still making environment-specific rendering explicit.

## Values Schema

`values.schema.json` gives Helm a type contract for the most important values.

It catches mistakes such as:

- missing workload definitions
- non-integer replica counts
- invalid image pull policies
- malformed secret-backed environment variables

The schema is intentionally focused. It validates the stable chart contract without trying to describe every optional platform feature before those templates exist.

## Workload Templates

The workload template lives at:

```text
deploy/helm/cpemon/templates/workloads.yaml
```

It loops over `.Values.workloads` and renders one Deployment and one Service for each enabled workload.

The template keeps these concerns reusable through `_helpers.tpl`:

- stable labels and selectors
- image registry, repository, tag, and pull policy resolution
- plain environment variables
- Secret-backed environment variables
- default affinity and tolerations

The rendered workloads keep the old `app` label for compatibility with existing ServiceMonitor and PDB selectors, while also adding Kubernetes recommended `app.kubernetes.io/*` labels for clearer ownership.

Secret-backed values are rendered with `valueFrom.secretKeyRef`; the chart does not render raw database passwords or HMAC secrets.

## ConfigMap and Secret References

`CCPU-54` adds a chart-owned ConfigMap for non-secret runtime configuration:

```text
cpemon-app-config
```

The ConfigMap stores values such as:

- `HTTP_ADDR`
- `GRAFANA_HOME_URL`
- `GRAFANA_SN_DASHBOARD_URL_TEMPLATE`
- `KIBANA_HOME_URL`
- `KIBANA_SN_LOGS_URL_TEMPLATE`

Workload env entries that use `valueFromConfig` render as `configMapKeyRef`.

Sensitive runtime inputs still render as external Secret references:

- `DB_DSN` -> Secret `cpemon-db`, key `dsn`
- `HMAC_SECRET` -> Secret `cpemon-acs-hmac`, key `hmac-secret`

The chart also references the image pull Secret:

- `cpemon-ecr-regcred`

These Secrets must exist before installing the chart. This chart intentionally does not create real Secret values.

## Optional Platform Features

`CCPU-55` adds optional platform integration templates. They are disabled by default in dev rendering and can be enabled through values:

```yaml
ingress:
  enabled: true
serviceMonitor:
  enabled: true
pdb:
  enabled: true
networkPolicy:
  enabled: true
```

The optional templates are:

| Template | Purpose |
| --- | --- |
| `templates/ingress.yaml` | Routes external HTTP paths to `acs-ingest` and `cpemon-api`. |
| `templates/servicemonitor.yaml` | Lets kube-prometheus-stack discover workload metrics Services. |
| `templates/pdb.yaml` | Adds PDBs for multi-replica workloads. |
| `templates/networkpolicy.yaml` | Adds a baseline default-deny egress posture plus explicit DNS/core egress allows. |

The conservative default is important: these resources depend on platform capabilities such as an ingress controller, Prometheus Operator CRDs, and NetworkPolicy enforcement.
