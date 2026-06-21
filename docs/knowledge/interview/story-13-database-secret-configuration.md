# Story 13: Database and Secret Configuration

## Q1: What is the goal of the Database and Secret Configuration story?

The goal is to cleanly define how CPEmon receives database configuration and sensitive runtime values in the EKS migration.

The story separates three concerns:

- non-secret configuration belongs in ConfigMaps or Helm values
- sensitive values belong in Kubernetes Secrets at runtime
- real secret material should be managed outside Git, ideally in AWS Secrets Manager and reconciled by External Secrets Operator

## Q1A: What did you decide for ESO, AWS Secrets Manager, and KMS?

I selected this model:

```text
AWS Secrets Manager
        |
        | encrypted at rest with AWS KMS
        v
External Secrets Operator on EKS
        |
        | authenticated through IRSA
        v
Kubernetes Secret
        |
        v
CPEmon workloads through secretKeyRef
```

The reason is separation of responsibility. Git owns the desired contract, AWS Secrets Manager owns the real values, KMS protects encryption at rest, IRSA gives the operator AWS permissions without static keys, and the application keeps consuming normal Kubernetes Secrets.

## Q1B: Why not just use Kubernetes Secrets?

Kubernetes Secrets are the runtime projection, not the whole source-of-truth story.

If I only use manually created Kubernetes Secrets, I still need to answer:

- where the real values are stored outside the cluster
- who can read or rotate them
- how access is audited
- how a recreated cluster gets the same secret contract
- how GitOps reconciles desired state without storing credentials

External Secrets Operator gives that reconciliation layer while leaving the workload interface unchanged.

## Q1C: What is the difference between Secrets Manager and KMS?

Secrets Manager stores and versions the secret value.

KMS protects the cryptographic key material used by AWS services to encrypt the secret at rest.

IAM controls who can call APIs like `secretsmanager:GetSecretValue`, and KMS policy can add another boundary for using the encryption key.

In an interview, I would explain it as:

```text
Secrets Manager answers: where is the secret?
KMS answers: how is the secret protected at rest?
IAM/IRSA answers: who is allowed to read it from EKS?
ESO answers: how does it become a Kubernetes Secret?
```

## Q1D: Why use IRSA for ESO?

ESO needs AWS API permissions to read from Secrets Manager.

I do not want long-lived AWS access keys stored in Kubernetes. IRSA lets the ESO service account assume an IAM role through the EKS OIDC provider.

That gives least privilege:

```text
service account external-secrets/external-secrets
        |
        v
IAM role trusted by EKS OIDC subject
        |
        v
secretsmanager:GetSecretValue only for approved CPEmon secret ARNs
```

## Q1E: What did you define for the ESO IAM policy contract?

I added a Terraform module:

```text
infra/terraform/modules/external_secrets_irsa
```

It creates an IAM role for the External Secrets Operator service account and attaches a least-privilege policy.

The allowed Kubernetes identity is:

```text
system:serviceaccount:external-secrets:external-secrets
```

The allowed AWS actions are:

```text
secretsmanager:DescribeSecret
secretsmanager:GetSecretValue
kms:Decrypt
kms:DescribeKey
```

KMS permissions are only included when customer managed KMS key ARNs are supplied.

## Q1F: What secret ARN pattern did you use for CPEmon dev?

The default dev pattern is:

```text
arn:aws:secretsmanager:<region>:*:secret:cpemon/dev/*
```

The important design is the path convention:

```text
cpemon/dev/<secret-name>
```

That gives us an environment boundary and avoids a policy that can read every secret in the AWS account.

## Q1G: What is the security improvement over static AWS keys?

Static AWS keys in Kubernetes create a long-lived credential that can be copied, leaked, or forgotten.

With IRSA, the ESO Pod receives short-lived credentials through the EKS OIDC trust chain. The IAM role trust policy is bound to one Kubernetes service account, and the permission policy is scoped to CPEmon secret ARNs. That means the blast radius is much smaller and the access path is auditable.

## Q1H: What ESO resources did you template?

I added optional Helm templates for:

```text
SecretStore/cpemon-aws-secretsmanager
ExternalSecret/cpemon-db
ExternalSecret/cpemon-acs-hmac
ExternalSecret/mysql-auth
```

They are controlled by:

```yaml
externalSecrets:
  enabled: false
```

The default is false because ESO CRDs may not exist in every local cluster.

## Q1I: How do the ExternalSecrets avoid storing secret values in Git?

The chart stores only remote references:

```yaml
remoteRef:
  key: cpemon/dev/cpemon-db
  property: dsn
```

That says where ESO should fetch the value from, not what the value is.

The actual DSN, HMAC secret, and MySQL passwords live in AWS Secrets Manager.

## Q1J: Why is it useful that workloads still use `secretKeyRef`?

It keeps the application boundary stable.

The workload does not care whether `cpemon-db` was created manually, by ESO, by SOPS, or by a bootstrap process. It only needs:

```yaml
valueFrom:
  secretKeyRef:
    name: cpemon-db
    key: dsn
```

That makes the secret source replaceable without changing application code.

## Q2: What did you decide for MySQL in Step 1?

For Step 1, I kept MySQL inside the EKS application boundary.

That means MySQL still runs in the `cpemon` namespace for now, and CPEmon workloads connect through `DB_DSN`.

The important part is that the application contract is stable:

```text
DB_DSN -> Kubernetes Secret cpemon-db -> key dsn
```

Later, the content of that Secret can point to RDS without changing application code.

## Q3: Why not move to RDS immediately?

RDS is a good future production direction, but doing it immediately would combine too many migrations.

This story is already changing the configuration and secret model. If I also moved the database to RDS, I would need to solve subnet groups, security groups, RDS Terraform, backup policy, maintenance windows, credential rotation, and data migration at the same time.

I wanted the migration to be layered:

```text
stabilize app contract -> clean secret delivery -> later managed database
```

That is easier to validate and easier to explain in an interview.

## Q4: Is keeping MySQL in Kubernetes production-grade?

Not as a final answer for a serious production platform.

In-cluster MySQL can be acceptable for a lab, MVP, or early migration step, especially when the main learning goal is Kubernetes packaging and secret management.

For production, I would normally prefer a managed database such as RDS because it gives better operational primitives around backups, maintenance, patching, storage, monitoring, and failover.

## Q5: What is the key design boundary?

The key design boundary is `DB_DSN`.

The application reads one environment variable. The deployment layer decides where that value comes from.

In Step 1:

```text
cpemon-api / acs-ingest / cpemon-writer
        |
        v
DB_DSN env var
        |
        v
Kubernetes Secret cpemon-db, key dsn
```

In a later hardening step, External Secrets Operator can create that same Kubernetes Secret from AWS Secrets Manager.

## Q6: What would change when moving to RDS later?

The application code should not need to change.

The change should happen behind the secret boundary:

- provision RDS with Terraform
- store the RDS username, password, host, port, and database name in AWS Secrets Manager
- have External Secrets Operator sync the app-facing Kubernetes Secret
- update the `dsn` value
- roll the workloads so they pick up the new Secret

That is the benefit of keeping the app contract stable.

## Q7: What did you actually change for CCPU-61?

I documented the MySQL deployment strategy decision for Step 1.

The key files are:

```text
ADR/cloud-platform-upgrade-step1-mysql-in-eks.md
docs/knowledge/database-secret-configuration.md
docs/knowledge/interview/story-13-database-secret-configuration.md
```

No application runtime logic changed in this subtask.

## Q8: How would you explain this in 60 seconds?

I kept MySQL in EKS for Step 1 because I wanted to reduce migration variables. The project was already changing the platform target, Helm packaging, and secret-management model. Moving to RDS at the same time would mix database migration, network design, Terraform RDS work, and credential rotation into one story. Instead, I stabilized the application contract: workloads read `DB_DSN` from a Kubernetes Secret. That Secret can later be populated by External Secrets Operator from AWS Secrets Manager, and its value can point either to in-cluster MySQL or RDS. This gives a clean path to production without overloading the first migration step.

## Q9: Did you use a MySQL chart dependency?

Not for Step 1.

I templated the existing MySQL shape directly in the CPEmon Helm chart and kept it disabled by default.

That was intentional. A dependency such as a community MySQL chart can be useful later, but it brings a larger values model and chart lifecycle into this story. The immediate goal was to make the current database dependency reviewable in Helm while preserving the secret boundary.

## Q10: What does the optional MySQL template render?

When `mysql.enabled=true`, it renders:

```text
ConfigMap/mysql-config
Deployment/mysql
Service/mysql
optional PersistentVolumeClaim
```

The template references Secret `mysql-auth` for:

```text
mysql-root-password
mysql-username
mysql-password
mysql-database
```

It does not create real credential values.

## Q11: Why is MySQL disabled by default?

Because the chart's main job is to package CPEmon application workloads.

MySQL is a data dependency. Some environments may use in-cluster MySQL, while future production environments may use RDS. Keeping `mysql.enabled=false` by default avoids accidental database installs and makes the database ownership decision explicit per environment.

## Q12: How would you explain the chart-dependency decision in an interview?

I avoided adding a MySQL chart dependency in Step 1 because the goal was not to adopt a full database chart lifecycle yet. The project needed a small, reviewable bridge from the current raw MySQL manifest to Helm. I copied the existing shape into an optional chart template, kept it disabled by default, and made sure it only references `mysql-auth` rather than storing credentials. That leaves the path open for RDS or a dedicated dependency later without making this story too broad.

## Q13: Why is `DB_DSN` considered secret material?

A database DSN often contains the username, password, host, database name, and connection options in one string.

Even if the host and database name are not secret, the password usually is. It is safer to treat the whole DSN as sensitive and keep it out of Git, rendered manifests, and logs.

## Q14: What did you change for `DB_DSN` in the raw manifests?

The raw app manifests now read `DB_DSN` from Kubernetes Secret `cpemon-db`, key `dsn`.

The pattern is:

```yaml
- name: DB_DSN
  valueFrom:
    secretKeyRef:
      name: cpemon-db
      key: dsn
```

That matches the Helm chart secret-reference model.

## Q15: What logging issue did you fix?

The config loader used to log the raw DSN at startup.

That is risky because application logs are often shipped to centralized systems like Elasticsearch or cloud logging. A secret printed once at startup can become searchable for a long time.

The app now logs only:

```text
DB_DSN_set=true
```

That proves the variable was configured without exposing the value.

## Q16: Why keep a local fallback DSN in code?

It preserves local developer convenience for running the app outside Kubernetes.

The important production boundary is that Kubernetes manifests supply `DB_DSN` from a Secret. When the environment variable is present, the fallback is not used.

In a stricter production codebase, I might make `DB_DSN` required and fail fast if it is missing. For this migration step, I kept backward compatibility but stopped leaking the DSN.

## Q17: How would you summarize CCPU-63?

I refactored `DB_DSN` handling so Kubernetes deployments no longer commit a literal database connection string, and the app no longer logs the raw DSN. The workloads now consume `DB_DSN` from Secret `cpemon-db` key `dsn`, which aligns raw YAML with the Helm chart and prepares the project for External Secrets Operator.

## Q18: What belongs in ConfigMap versus Secret?

ConfigMap is for non-sensitive runtime configuration, such as ports, URLs, feature flags, and batch sizes.

Secret is for sensitive runtime material, such as database passwords, DSNs, tokens, and HMAC keys.

The practical rule is: if exposing the value in Git, logs, screenshots, or `kubectl get yaml` would be a security problem, use Secret.

## Q19: What did you move into the raw app ConfigMap?

I added `k8s/app/cpemon-app-config.yaml`.

It contains:

```text
HTTP_ADDR
GRAFANA_HOME_URL
GRAFANA_SN_DASHBOARD_URL_TEMPLATE
KIBANA_HOME_URL
KIBANA_SN_LOGS_URL_TEMPLATE
WORKER_INTERVAL
BATCH_SIZE
```

These are environment-specific but not secret.

## Q20: Why is this useful if Helm already has a ConfigMap?

The raw YAML still exists as the MVP baseline and migration reference.

Aligning the raw manifests with the Helm chart makes the migration easier to explain. Both paths now use the same mental model:

```text
non-secret config -> ConfigMap
secret config -> Secret
application reads env vars
```

## Q21: How would you summarize CCPU-64?

I moved non-sensitive runtime configuration out of the raw Deployment env literals and into `cpemon-app-config`. The workloads now source those values with `configMapKeyRef`, while sensitive values remain in Secrets. This makes the raw manifests match the Helm chart boundary and gives a clearer interview story around ConfigMap versus Secret.

## Q22: What is the Secret contract for CPEmon?

The raw manifest and Helm chart agree on these Secrets:

| Secret | Key | Purpose |
| --- | --- | --- |
| `cpemon-db` | `dsn` | Application MySQL DSN |
| `cpemon-acs-hmac` | `hmac-secret` | ACS webhook HMAC validation |
| `mysql-auth` | `mysql-root-password` | MySQL root password |
| `mysql-auth` | `mysql-username` | MySQL app username |
| `mysql-auth` | `mysql-password` | MySQL app password |
| `mysql-auth` | `mysql-database` | MySQL database name |

## Q23: Why add a Secret template file instead of a real Secret?

A real Secret manifest would still put secret material in Git, even if base64 encoded.

Base64 is encoding, not encryption. Anyone with repo access can decode it.

The template file documents the expected Secret names and keys but uses placeholders. Real values should come from a secure bootstrap path or External Secrets Operator.

## Q24: What did you change for `HMAC_SECRET`?

`acs-ingest` used to have a literal placeholder value committed directly in the Deployment.

It now uses Secret `cpemon-acs-hmac`, key `hmac-secret`.

That makes HMAC handling consistent with `DB_DSN`: the app reads an environment variable, but Kubernetes sources it from a Secret.

## Q25: What is the interview-level lesson from CCPU-65?

The lesson is that Git should own the Secret contract, not the Secret values.

I made the required Kubernetes Secrets reviewable by adding a template file, and I changed workloads to consume sensitive values through `secretKeyRef`. That gives a clean bridge to External Secrets Operator later, where AWS Secrets Manager becomes the source of truth for the actual secret material.

## Q26: How do you verify that `cpemon-api` uses the DB Secret correctly?

I verify the wiring before looking at application behavior:

```powershell
kubectl -n cpemon get secret cpemon-db
kubectl -n cpemon get deploy cpemon-api -o yaml
```

The expected env block is:

```yaml
- name: DB_DSN
  valueFrom:
    secretKeyRef:
      name: cpemon-db
      key: dsn
```

Then I check rollout and logs:

```powershell
kubectl -n cpemon rollout status deployment/cpemon-api
kubectl -n cpemon logs deployment/cpemon-api --tail=120
```

The success signal is no `failed to initialize database`, and ideally a startup log like `database connection established`.

## Q27: Why not decode the Secret during verification?

Because the goal is to prove the application can use the Secret, not to expose the credential.

In production, decoding and pasting secrets into terminals, tickets, or chat creates a new leak path. A safer check verifies:

- Secret exists
- required key exists
- Deployment references the correct Secret/key
- application starts successfully
- logs do not show DB initialization failure

## Q28: What script did you add for `cpemon-api` DB verification?

I added:

```text
scripts/verify-cpemon-api-db.ps1
```

It checks the Secret shape, Deployment `DB_DSN` wiring, rollout status, recent logs, and `/healthz` through port-forward.

## Q29: What is the validation boundary for CCPU-66?

Local validation can prove that the script parses, documentation exists, Go tests pass, and Helm still renders.

Live validation requires:

- `kubectl`
- kubeconfig pointing to a live cluster
- namespace `cpemon`
- Secret `cpemon-db`
- running MySQL
- running `cpemon-api`

Without those, it would be dishonest to claim live DB connectivity.

## Q30: How would you summarize CCPU-66?

I added a safe verification path for `cpemon-api` database connectivity. The script checks that `DB_DSN` comes from `cpemon-db/dsn`, waits for the API rollout, inspects logs for database initialization failures, and checks `/healthz`. It deliberately does not print or decode the database Secret. That makes the verification useful for operations and safe from a credential-handling perspective.

## Q31: Why does `cpemon-writer` need a separate DB verification from `cpemon-api`?

Because `cpemon-api` and `cpemon-writer` prove different runtime paths.

`cpemon-api` proves that the API can initialize its DB connection and serve health checks.

`cpemon-writer` proves the queue worker path:

```text
DB_DSN -> appdb.Init -> worker loop -> runOnce -> SELECT ingest_events -> UPDATE ingest_events
```

That means a writer check should look for startup success and worker-loop DB errors.

## Q32: How do you verify that `cpemon-writer` is configured correctly?

I verify both sensitive and non-sensitive runtime inputs:

```powershell
kubectl -n cpemon get secret cpemon-db
kubectl -n cpemon get configmap cpemon-app-config
kubectl -n cpemon get deploy cpemon-writer -o yaml
```

The expected wiring is:

```yaml
- name: DB_DSN
  valueFrom:
    secretKeyRef:
      name: cpemon-db
      key: dsn
- name: WORKER_INTERVAL
  valueFrom:
    configMapKeyRef:
      name: cpemon-app-config
      key: WORKER_INTERVAL
- name: BATCH_SIZE
  valueFrom:
    configMapKeyRef:
      name: cpemon-app-config
      key: BATCH_SIZE
```

That proves secrets and non-secret config are separated correctly.

## Q33: What failure signal matters most for the writer DB write path?

The writer-specific signal is:

```text
cpemon-writer runOnce error
```

`failed to initialize database` means startup DB connection failed. `runOnce error` means the service started, but the worker could not query or update `ingest_events`. That often points to schema drift, missing table, permissions, or a DB connection problem after startup.

## Q34: What script did you add for `cpemon-writer` verification?

I added:

```text
scripts/verify-cpemon-writer-db.ps1
```

It checks the Secret shape, ConfigMap shape, Deployment env wiring, rollout status, recent logs, and `/healthz`.

## Q35: How would you prove the full writer path end to end?

The strongest proof is to insert an approved test row into `ingest_events`, wait for the worker loop, then confirm:

```text
processing ingest_event
status='done'
```

I would only do that in a dev or test environment with an approved test-data process. In production, I would rely on controlled synthetic checks, metrics, and logs rather than manually inserting data.

## Q36: How would you summarize CCPU-67?

I added a safe verification path for `cpemon-writer` that checks both the secret-backed DB connection and the worker write-path signals. The script confirms `DB_DSN` comes from `cpemon-db/dsn`, worker settings come from `cpemon-app-config`, rollout succeeds, logs do not show DB startup or `runOnce` errors, and `/healthz` responds. The runbook explains how to extend that into an end-to-end queue proof when inserting test data is allowed.

## STAR Story

Situation:

CPEmon was moving from a YAML-first MVP toward EKS, Helm, and better secret management. The application already used MySQL, but the platform story needed to decide whether to keep it in Kubernetes or move immediately to RDS.

Task:

I needed to choose a database deployment strategy that supported the secret-management story without expanding the scope too far.

Action:

I kept MySQL in EKS for Step 1, documented RDS as a future production hardening direction, and made `DB_DSN` the stable application contract. I recorded which Kubernetes Secrets the workloads expect and why real credentials should later come from AWS Secrets Manager through External Secrets Operator.

Result:

The migration has a clearer sequence. The team can improve Helm and secret handling now, then move to RDS later behind the same `DB_DSN` boundary. That makes the work easier to validate and easier to explain.
