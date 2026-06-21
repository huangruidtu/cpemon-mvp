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
