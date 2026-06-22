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

`CCPU-115` adds the first Argo Rollouts migration boundary. `cpemon-api` can
render as an Argo Rollouts `Rollout` when its workload-level switch is enabled:

```yaml
workloads:
  cpemonApi:
    rollout:
      enabled: true
```

This switch is intentionally scoped to `cpemonApi`. `acs-ingest` and
`cpemon-writer` continue to render as Deployments.

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

For the full operator workflow, including pre-apply validation, future install checks, rollback, and troubleshooting, see:

```text
ops/runbooks/helm-cpemon-application.md
```

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
| `externalSecrets` | Optional ESO `SecretStore` and `ExternalSecret` resources for syncing runtime Secrets from AWS Secrets Manager. |
| `mysql` | Optional in-cluster MySQL resources for Step 1 compatibility. |
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

## cpemon-api Rollout Mode

When `workloads.cpemonApi.rollout.enabled=true`, the workload template renders:

```text
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata.name: cpemon-api
```

The Rollout keeps the same pod template, labels, selector, image, env,
Secret references, ports, probes, resources, affinity, tolerations, and
Service selector used by the previous Deployment path.

The initial canary strategy renders an empty `steps` list:

```yaml
strategy:
  canary:
    stableService: cpemon-api-stable
    canaryService: cpemon-api-canary
    steps: []
```

That is deliberate for `CCPU-115` and `CCPU-116`. The first task replaces only
the workload controller kind. The next task adds the stable and canary Service
boundary. Later Argo Rollouts subtasks add weighted canary steps, Prometheus
AnalysisTemplates, and promotion/abort demos.

When rollout mode is enabled, the chart also renders:

```text
Service/cpemon-api
Service/cpemon-api-stable
Service/cpemon-api-canary
```

`cpemon-api` remains as the existing application Service so current ingress,
monitoring, and operator commands keep a stable entrypoint. The stable/canary
Services are the Argo Rollouts traffic-shaping boundary. They start with the
same selector labels as the Rollout pod template; the Rollouts controller can
then manage them as ReplicaSets change.

Validate the first Rollout boundary with:

```powershell
make cpemon-api-rollout-check
make cpemon-api-rollout-services-check
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

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
- Kafka producer and consumer settings such as `KAFKA_BOOTSTRAP_SERVERS`, topic names, `KAFKA_PRODUCER_ENABLED`, and `KAFKA_CONSUMER_ENABLED`

Workload env entries that use `valueFromConfig` render as `configMapKeyRef`.

Sensitive runtime inputs still render as external Secret references:

- `DB_DSN` -> Secret `cpemon-db`, key `dsn`
- `HMAC_SECRET` -> Secret `cpemon-acs-hmac`, key `hmac-secret`

The chart also references the image pull Secret:

- `cpemon-ecr-regcred`

These Secrets must exist before installing the chart. This chart intentionally does not create real Secret values.

## cpemon-writer Kafka Consumer Configuration

Story 10 adds writer-side Kafka consumer configuration while keeping the
consumer disabled by default:

```yaml
appConfig:
  kafkaConsumerEnabled: false
  kafkaConsumerGroupId: cpemon-writer
  kafkaConsumerReadTimeout: 5s
  kafkaConsumerCommitTimeout: 5s
  kafkaConsumerMaxRetries: "3"
  kafkaConsumerRetryBackoff: 1s
```

The chart wires these values only into `cpemon-writer` because `acs-ingest` is
the producer and `cpemon-writer` is the consumer. The shared topic values remain
in `appConfig` so producer and consumer agree on the event contracts.

## Optional Platform Features

`CCPU-55` adds optional platform integration templates. They are disabled in the
base values file and can be enabled through environment values:

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

For the dev observability story, `values-dev.yaml` enables `serviceMonitor`
because `monitoring-dev` installs kube-prometheus-stack first. The rendered
ServiceMonitor uses:

| Field | Value |
| --- | --- |
| Namespace | `monitoring` |
| Prometheus release label | `release: kps` |
| Scrape port | `metrics` |
| Scrape path | `/metrics` |
| Selected services | `cpemon-api`, `acs-ingest`, `cpemon-writer` |

Validate it with:

```powershell
make cpemon-servicemonitor-check
```

## Migration Decision

The raw Kubernetes YAML remains useful as historical MVP context, but the Helm chart is the migration target for application packaging.

The decision boundary is:

```text
Terraform provisions cloud infrastructure.
Kubernetes add-ons provide platform capabilities.
Helm packages the CPEmon application.
Argo CD can later deploy the chart from Git.
```

The chart does not replace Terraform, and it does not create real production secrets. It provides a repeatable application rendering model that future CI/CD or GitOps tooling can consume.

## Optional MySQL Template

`CCPU-62` keeps MySQL in EKS for Step 1 and templates the existing MVP MySQL shape directly in this chart instead of adding an external chart dependency.

The MySQL template is disabled by default:

```yaml
mysql:
  enabled: false
```

When enabled, it renders:

- `ConfigMap` `mysql-config`
- `Deployment` `mysql`
- `Service` `mysql`
- optional `PersistentVolumeClaim` if `mysql.persistence.create=true`

The template references, but does not create, Secret `mysql-auth`:

```text
mysql-root-password
mysql-username
mysql-password
mysql-database
```

This keeps real database credentials outside Helm values and prepares the chart for a later External Secrets Operator integration.

## External Secrets Operator Resources

`CCPU-156` adds optional External Secrets Operator resources to the chart.

They are disabled by default:

```yaml
externalSecrets:
  enabled: false
```

This conservative default matters because ESO resources require CRDs that may not exist in every local or test cluster.

When enabled, the chart renders:

- `SecretStore` `cpemon-aws-secretsmanager`
- `ExternalSecret` `cpemon-db`
- `ExternalSecret` `cpemon-acs-hmac`
- `ExternalSecret` `mysql-auth`

The chart stores only remote secret paths and properties:

```yaml
externalSecrets:
  secrets:
    db:
      remoteKey: cpemon/dev/cpemon-db
      data:
        - secretKey: dsn
          remoteProperty: dsn
```

It does not store secret values.

The resulting Kubernetes Secrets keep the existing workload contract:

| Kubernetes Secret | Key(s) | Consumers |
| --- | --- | --- |
| `cpemon-db` | `dsn` | `cpemon-api`, `acs-ingest`, `cpemon-writer` |
| `cpemon-acs-hmac` | `hmac-secret` | `acs-ingest` |
| `mysql-auth` | `mysql-root-password`, `mysql-username`, `mysql-password`, `mysql-database` | optional MySQL template |

Render with ESO enabled:

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml --set externalSecrets.enabled=true
```

The expected rendered YAML contains `remoteRef.key` and `remoteRef.property`, not decoded credentials.
