# Database and Secret Configuration

## Why This Story Exists

`CCPU-7` moves CPEmon from ad hoc database and secret handling toward a cloud-platform model.

Story 6 made the application deployable through Helm. Story 7 answers the next question:

```text
How do database settings and sensitive values enter the application safely?
```

The answer is not to put passwords in Helm values. Helm should define the shape of configuration and Secret references. Real secret material should live in a controlled secret system and be synchronized into Kubernetes.

## Target Model

The selected model for this story is:

```text
AWS Secrets Manager + AWS KMS
        |
        v
External Secrets Operator on EKS
        |
        v
Kubernetes Secret
        |
        v
CPEmon workloads through secretKeyRef
```

The important boundary:

- Git stores templates, names, keys, and expected references.
- AWS Secrets Manager stores real secret values.
- AWS KMS protects secret encryption at rest.
- IRSA gives External Secrets Operator AWS permission without static AWS keys.
- Kubernetes Secrets become the local cluster projection consumed by Pods.

## CCPU-154: ESO, AWS Secrets Manager, and KMS Decision

`CCPU-154` records the secret-management architecture decision for Story 7.

The ADR is:

```text
ADR/cloud-platform-upgrade-eso-aws-secrets-manager-kms.md
```

### Decision

Use External Secrets Operator with AWS Secrets Manager, AWS KMS, and IRSA:

```text
AWS Secrets Manager
        |
        | encrypted at rest with AWS KMS
        v
External Secrets Operator on EKS
        |
        | authenticated through IRSA
        v
Kubernetes Secret in namespace cpemon
        |
        v
CPEmon workloads through secretKeyRef
```

### Boundary

Git owns the declarative contract:

- `SecretStore` or `ClusterSecretStore` manifests
- `ExternalSecret` manifests
- Kubernetes Secret names and keys
- workload `secretKeyRef` wiring
- validation scripts and runbooks

Git does not own real secret values.

AWS Secrets Manager owns secret material. AWS KMS protects the encryption model for those secrets. IRSA gives the ESO controller permission to read only approved secrets without static AWS keys.

### Why This Is Better Than Kubernetes Secret Alone

A Kubernetes Secret is the local runtime projection that Pods can consume. It is not, by itself, a full production secret-management system.

The missing pieces are:

- central source of truth outside the cluster
- IAM-based access control
- cloud audit trail
- key-management boundary
- future rotation workflows
- GitOps-friendly reconciliation

External Secrets Operator fills the delivery gap while keeping applications on the standard Kubernetes Secret interface.

### Deferred

RDS credentials are deferred because Step 1 intentionally keeps MySQL in EKS. Kafka credentials are deferred because Kafka is not part of the current MVP runtime path. The ESO pattern can support both later without changing the application contract.

### Interview Point

I separated the secret source from the Kubernetes runtime projection. AWS Secrets Manager is the source of truth, KMS protects encryption at rest, IRSA gives ESO least-privilege AWS access, and Kubernetes Secrets remain the local interface that Pods consume. That is a production-style boundary because Git can own the desired shape without owning the secret values.

## CCPU-155: ESO IRSA and IAM Policy Contract

`CCPU-155` defines the Terraform contract for External Secrets Operator AWS access.

The module is:

```text
infra/terraform/modules/external_secrets_irsa
```

The dev wiring is in:

```text
infra/terraform/envs/dev/main.tf
infra/terraform/envs/dev/variables.tf
infra/terraform/envs/dev/outputs.tf
infra/terraform/envs/dev/terraform.tfvars.example
```

### Service Account Contract

The assumed Kubernetes identity is:

```text
namespace: external-secrets
service account: external-secrets
OIDC subject: system:serviceaccount:external-secrets:external-secrets
```

The ESO Helm installation later must annotate that service account with the Terraform output:

```text
external_secrets_irsa_role_arn
```

### IAM Policy Contract

The module grants only:

```text
secretsmanager:DescribeSecret
secretsmanager:GetSecretValue
kms:Decrypt
kms:DescribeKey
```

The KMS permissions are included only when customer managed KMS key ARNs are supplied.

### Secret ARN Contract

The dev default secret ARN pattern is:

```text
arn:aws:secretsmanager:<region>:*:secret:cpemon/dev/*
```

That gives CPEmon a clear naming convention without committing secret values.

### Interview Point

I defined ESO access as an IRSA contract instead of storing AWS access keys in Kubernetes. The trust policy allows only the `external-secrets/external-secrets` service account to assume the role, and the permission policy allows reading only approved Secrets Manager ARNs plus optional KMS decrypt on approved keys. This is least privilege across Kubernetes identity, AWS IAM, Secrets Manager, and KMS.

## CCPU-156: SecretStore and ExternalSecret Templates

`CCPU-156` adds optional ESO resources to the CPEmon Helm chart.

The template is:

```text
deploy/helm/cpemon/templates/external-secrets.yaml
```

The values contract is:

```text
deploy/helm/cpemon/values.yaml
deploy/helm/cpemon/values-dev.yaml
deploy/helm/cpemon/values.schema.json
```

### Resources Rendered

When `externalSecrets.enabled=true`, the chart renders:

- `SecretStore` `cpemon-aws-secretsmanager`
- `ExternalSecret` `cpemon-db`
- `ExternalSecret` `cpemon-acs-hmac`
- `ExternalSecret` `mysql-auth`

The resources are disabled by default because ESO CRDs may not exist in local clusters.

### Secret Contract Preserved

Workloads still read Kubernetes Secrets through `secretKeyRef`.

ESO only changes how those Kubernetes Secrets are produced:

```text
AWS Secrets Manager remote key/property
        |
        v
ExternalSecret
        |
        v
Kubernetes Secret
        |
        v
workload secretKeyRef
```

### No Secret Material in Git

The chart stores paths such as:

```text
cpemon/dev/cpemon-db
cpemon/dev/cpemon-acs-hmac
cpemon/dev/mysql-auth
```

and properties such as:

```text
dsn
hmac-secret
mysql-password
```

It does not store the values for those properties.

### Interview Point

I kept the workload contract stable and introduced ESO behind it. The Helm chart can render `ExternalSecret` resources that point to AWS Secrets Manager remote keys and JSON properties, but the workloads still consume normal Kubernetes Secrets. That means application code, Deployment env wiring, and Helm workload templates do not need to know where the real secret value comes from.

## CCPU-61: MySQL Deployment Strategy for Step 1

For Step 1, CPEmon keeps MySQL inside the EKS application boundary.

This is a migration sequencing decision, not a claim that in-cluster MySQL is the final production design.

### Decision

Keep MySQL in the `cpemon` namespace for the current Step 1 platform work.

Use these application contracts:

| Purpose | Kubernetes Secret | Key |
| --- | --- | --- |
| Application MySQL DSN | `cpemon-db` | `dsn` |
| MySQL container auth | `mysql-auth` | `mysql-root-password`, `mysql-username`, `mysql-password`, `mysql-database` |
| ACS webhook HMAC | `cpemon-acs-hmac` | `hmac-secret` |

The Helm chart already points application workloads at Secret references. The next secret-management subtasks will define how those Secrets can be produced by External Secrets Operator.

### Why Keep MySQL in EKS Now

The current story is about configuration and secret delivery. Moving to RDS now would add a second major migration:

- database network design
- Terraform RDS module design
- DB subnet groups and security groups
- RDS backup and maintenance policy
- migration of existing data
- RDS credential rotation behavior

Those are real production concerns, but they would make this story harder to validate and harder to explain.

The cleaner interview answer is:

```text
First stabilize the application and secret contract.
Then move the database implementation behind that contract.
```

### RDS Future Direction

RDS is a future production improvement.

When this project is ready for RDS, the expected path is:

1. Add Terraform for RDS subnet group, security group, parameter group, and instance or cluster.
2. Store RDS credentials in AWS Secrets Manager.
3. Let External Secrets Operator sync the app-facing `cpemon-db` Secret.
4. Change `DB_DSN` content, not application code.
5. Validate application connectivity and migration behavior.

This is why keeping `DB_DSN` as the application boundary is useful. The application should not care whether the MySQL endpoint is an in-cluster Service or an RDS endpoint.

## What This Proves

For `CCPU-61`, the proof is a documented architecture decision.

It proves:

- the current database deployment strategy is intentional
- RDS is deferred for scope control, not forgotten
- `DB_DSN` remains the stable application contract
- secret material will stay outside Git

It does not prove:

- live MySQL pod startup
- live AWS Secrets Manager synchronization
- RDS connectivity
- database failover

Those belong to later validation and hardening tasks.

## Interview Summary

I kept MySQL in EKS for Step 1 because the project was already changing platform layers: EKS, Helm, and secret management. Moving to RDS at the same time would mix database migration with secret-delivery work. I kept the application contract stable through `DB_DSN`, moved sensitive values behind Kubernetes Secret references, and documented RDS as the future production direction. This lets the team improve secret management now and later swap the database endpoint with less application impact.

## CCPU-62: Helmize MySQL or Add Chart Dependency

The decision for `CCPU-62` is to template the current MySQL shape directly in the CPEmon Helm chart, behind `mysql.enabled=false` by default.

### Why Direct Template Instead of Dependency

An external MySQL chart dependency is useful when the project is ready to delegate database lifecycle details to a maintained chart. For this Step 1 story, that adds more moving parts than needed:

- dependency version management
- upstream chart values model
- chart update review
- a larger set of generated resources
- more behavior to explain before the secret boundary is stable

The current goal is smaller:

```text
preserve existing MySQL behavior -> make it optional and reviewable in Helm -> keep credentials external
```

### What the Template Renders

When enabled, the chart renders:

| Resource | Purpose |
| --- | --- |
| `ConfigMap/mysql-config` | MySQL tuning file copied from the current raw manifest. |
| `Deployment/mysql` | In-cluster MySQL workload using `mysql:8.4`. |
| `Service/mysql` | Stable ClusterIP endpoint for application pods. |
| optional PVC | Created only when `mysql.persistence.create=true`. |

The template references `mysql-auth` but never stores real password values.

### Why Disabled by Default

The default chart still represents the CPEmon application workloads.

MySQL is a data dependency. It is enabled only when the environment wants this chart to own the in-cluster MySQL workload. Keeping it off by default avoids surprising installs and keeps future RDS migration clean.

### Interview Point

I did not add a heavy MySQL chart dependency yet because the project needed a small, reviewable migration step. I templated the existing MySQL resource shape directly, kept it optional, and preserved the secret boundary by referencing `mysql-auth` instead of putting credentials in values. This keeps the Step 1 path understandable while leaving room to replace in-cluster MySQL with RDS or a dedicated database chart later.

## CCPU-63: Refactor DB_DSN Configuration

`DB_DSN` is sensitive because a MySQL DSN usually contains username, password, host, port, database name, and connection options.

For `CCPU-63`, the project tightens this boundary in two places:

1. Raw Kubernetes application manifests now read `DB_DSN` from Secret `cpemon-db`, key `dsn`.
2. The Go config loader no longer prints the raw DSN in logs.

### Why This Matters

Kubernetes manifests and application logs are both common leak paths.

If a DSN is committed directly into a Deployment, the credential leaks through:

- Git history
- pull request diffs
- rendered YAML
- kubectl output
- screenshots and interview demos

If the app logs the DSN at startup, the credential can leak through:

- pod logs
- log shipping agents
- Kibana or other log search tools
- incident tickets copied from logs

### New Raw Manifest Pattern

The raw manifests now use:

```yaml
- name: DB_DSN
  valueFrom:
    secretKeyRef:
      name: cpemon-db
      key: dsn
```

This matches the Helm chart pattern and keeps `DB_DSN` as the application contract while moving secret material out of the Deployment YAML.

### Logging Pattern

The app config log now records whether `DB_DSN` is set, not what it contains:

```text
config loaded: DB_DSN_set=true HTTPAddr=:8080 WorkerInterval=1s BatchSize=50
```

That is enough for basic troubleshooting without exposing credentials.

### What Still Remains

The local Go default still includes a localhost fallback DSN so developers can run the app outside Kubernetes. That fallback is not used by the EKS manifests when `DB_DSN` is supplied from a Secret.

Future subtasks will define how `cpemon-db` is created through External Secrets Operator and AWS Secrets Manager.

### Interview Point

I treated `DB_DSN` as secret material, not just configuration. I removed committed DSN values from the raw Kubernetes app manifests and changed the app startup log so it reports only whether the DSN is configured. That closes two common leak paths: Git/Kubernetes YAML and centralized logs.

## CCPU-64: Move Non-Sensitive Config to ConfigMap

`CCPU-64` aligns the raw Kubernetes app manifests with the Helm chart ConfigMap boundary.

The raw manifests now include:

```text
k8s/app/cpemon-app-config.yaml
```

This ConfigMap owns non-sensitive runtime configuration:

| Key | Used by |
| --- | --- |
| `HTTP_ADDR` | `cpemon-api`, `acs-ingest`, `cpemon-writer` |
| `GRAFANA_HOME_URL` | `cpemon-api` |
| `GRAFANA_SN_DASHBOARD_URL_TEMPLATE` | `cpemon-api` |
| `KIBANA_HOME_URL` | `cpemon-api` |
| `KIBANA_SN_LOGS_URL_TEMPLATE` | `cpemon-api` |
| `WORKER_INTERVAL` | `cpemon-writer` |
| `BATCH_SIZE` | `cpemon-writer` |

### Why ConfigMap

These values are environment-specific, but not secret.

Putting them in a ConfigMap makes the boundary explicit:

- non-sensitive runtime config goes to ConfigMap
- sensitive runtime config goes to Secret
- application code still reads normal environment variables

### Raw Manifest Pattern

The raw manifests now use:

```yaml
- name: HTTP_ADDR
  valueFrom:
    configMapKeyRef:
      name: cpemon-app-config
      key: HTTP_ADDR
```

This matches the Helm chart pattern from Story 6.

### Interview Point

I separated environment-specific but non-sensitive configuration from the Deployment manifests. The application still reads ordinary environment variables, but Kubernetes now sources those values from a ConfigMap. That makes the raw YAML easier to review and keeps the model consistent with the Helm chart.

## CCPU-65: Move Sensitive Config to Kubernetes Secret

`CCPU-65` completes the raw manifest split between ConfigMap and Secret.

The raw manifests now define the expected Secret shape in:

```text
k8s/app/cpemon-secrets.tmpl.yaml
```

This file is a template only. It uses placeholders such as `${CPEMON_DB_DSN}` and `${CPEMON_ACS_HMAC_SECRET}`. It must not be applied as-is to a real environment without substituting values through a secure process.

### Secret Contract

| Secret | Key | Used by |
| --- | --- | --- |
| `cpemon-db` | `dsn` | `cpemon-api`, `acs-ingest`, `cpemon-writer` |
| `cpemon-acs-hmac` | `hmac-secret` | `acs-ingest` |
| `mysql-auth` | `mysql-root-password` | MySQL container |
| `mysql-auth` | `mysql-username` | MySQL container |
| `mysql-auth` | `mysql-password` | MySQL container |
| `mysql-auth` | `mysql-database` | MySQL container |

### Why Template Secret Shape

The project needs two things at once:

- a reviewable contract showing which Kubernetes Secrets and keys the workloads expect
- no real secret material committed to Git

A `.tmpl.yaml` file gives that contract without storing credentials.

Later subtasks can replace manual substitution with External Secrets Operator:

```text
AWS Secrets Manager -> ExternalSecret -> Kubernetes Secret -> workload secretKeyRef
```

### HMAC Secret Refactor

`acs-ingest` no longer contains a literal `HMAC_SECRET` value. It now uses:

```yaml
- name: HMAC_SECRET
  valueFrom:
    secretKeyRef:
      name: cpemon-acs-hmac
      key: hmac-secret
```

This matches the Helm chart boundary and removes the last sensitive literal from the raw app Deployment env list.

### Interview Point

I documented the Kubernetes Secret contract without committing the actual secrets. The manifests now show exactly which Secrets and keys the application expects, while real values are left to a secure bootstrap or External Secrets Operator. This is the right GitOps boundary: Git owns desired structure, not secret material.

## CCPU-66: Verify cpemon-api DB Connection

`CCPU-66` adds a repeatable verification path for `cpemon-api` database connectivity.

The verification script is:

```text
scripts/verify-cpemon-api-db.ps1
```

The runbook is:

```text
ops/runbooks/cpemon-api-db-connection.md
```

### What the Script Checks

The script verifies:

- `kubectl` client and current context
- Secret `cpemon-db` exists in namespace `cpemon`
- Secret key `dsn` exists without printing the value
- `deployment/cpemon-api` reads `DB_DSN` from `cpemon-db/dsn`
- rollout status for `deployment/cpemon-api`
- recent logs for database initialization failures
- `/healthz` through a temporary port-forward

### Why This Is the Right Verification Boundary

The app initializes its database connection during startup:

```text
cfg.DBDSN -> appdb.Init(cfg.DBDSN) -> database connection established
```

So the most useful operational check is not to decode the Secret. It is to verify the Secret shape, workload wiring, rollout, logs, and health endpoint without exposing credentials.

### Local Boundary

If no live cluster or `kubectl` is available, this task can still validate:

- the verification script parses
- the docs and runbook exist
- Go tests pass
- Helm lint/template still pass

It cannot honestly claim live DB connectivity until a cluster, kubeconfig, MySQL, and required Secrets exist.

### Interview Point

I did not verify database connectivity by printing or decoding the database password. I created a safe operational check that confirms the Secret shape, verifies the Deployment consumes the right Secret key, waits for rollout, scans logs for DB initialization failures, and checks `/healthz`. That is closer to how I would debug this in production because it validates behavior without exposing credentials.

## CCPU-67: Verify cpemon-writer DB Write Path

`CCPU-67` adds a repeatable verification path for `cpemon-writer`.

The verification script is:

```text
scripts/verify-cpemon-writer-db.ps1
```

The runbook is:

```text
ops/runbooks/cpemon-writer-db-write-path.md
```

### Why Writer Verification Is Different

`cpemon-api` mostly proves startup DB connectivity. `cpemon-writer` proves the worker side of the queue pipeline:

```text
DB_DSN -> appdb.Init -> worker loop -> runOnce -> SELECT ingest_events -> UPDATE ingest_events
```

That means the useful checks include both connection and write-path signals.

### What the Script Checks

The script verifies:

- `kubectl` client and current context
- Secret `cpemon-db` exists in namespace `cpemon`
- Secret key `dsn` exists without printing the value
- ConfigMap `cpemon-app-config` contains `HTTP_ADDR`, `WORKER_INTERVAL`, and `BATCH_SIZE`
- `deployment/cpemon-writer` reads `DB_DSN` from `cpemon-db/dsn`
- `deployment/cpemon-writer` reads `WORKER_INTERVAL` and `BATCH_SIZE` from `cpemon-app-config`
- rollout status for `deployment/cpemon-writer`
- recent logs for database initialization failures
- recent logs for `cpemon-writer runOnce error`
- `/healthz` through a temporary port-forward

### Interview Point

For a worker service, a healthy process is not enough. I verified the Secret contract, ConfigMap contract, rollout, health endpoint, and worker-specific DB error signal. The key distinction is that `cpemon-writer` can connect successfully at startup but still fail later when querying or updating `ingest_events`, so I included `runOnce` log checks and documented an optional queue-row proof for environments where inserting test data is approved.
