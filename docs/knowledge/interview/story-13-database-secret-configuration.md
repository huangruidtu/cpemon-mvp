# Story 13: Database and Secret Configuration

## Q1: What is the goal of the Database and Secret Configuration story?

The goal is to cleanly define how CPEmon receives database configuration and sensitive runtime values in the EKS migration.

The story separates three concerns:

- non-secret configuration belongs in ConfigMaps or Helm values
- sensitive values belong in Kubernetes Secrets at runtime
- real secret material should be managed outside Git, ideally in AWS Secrets Manager and reconciled by External Secrets Operator

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

## STAR Story

Situation:

CPEmon was moving from a YAML-first MVP toward EKS, Helm, and better secret management. The application already used MySQL, but the platform story needed to decide whether to keep it in Kubernetes or move immediately to RDS.

Task:

I needed to choose a database deployment strategy that supported the secret-management story without expanding the scope too far.

Action:

I kept MySQL in EKS for Step 1, documented RDS as a future production hardening direction, and made `DB_DSN` the stable application contract. I recorded which Kubernetes Secrets the workloads expect and why real credentials should later come from AWS Secrets Manager through External Secrets Operator.

Result:

The migration has a clearer sequence. The team can improve Helm and secret handling now, then move to RDS later behind the same `DB_DSN` boundary. That makes the work easier to validate and easier to explain.
