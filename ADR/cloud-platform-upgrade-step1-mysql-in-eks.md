# ADR: Keep MySQL in EKS for Step 1

- Status: Accepted
- Date: 2026-06-21
- Decision owner: Huang Rui
- Related Jira: CCPU-7, CCPU-61
- Related components: MySQL, cpemon-api, acs-ingest, cpemon-writer, Helm, External Secrets Operator

## Context

The CPEmon MVP already uses MySQL as its primary store for queue tables and business data. The cloud platform upgrade is moving the application toward EKS, Helm, GitOps, and External Secrets Operator, but not every operational concern should change at the same time.

The database decision has two different layers:

- Data model decision: MySQL remains the primary relational store for CPEmon in this phase.
- Deployment decision: the current Step 1 platform keeps MySQL running inside Kubernetes instead of moving immediately to Amazon RDS.

This story is focused on database and secret configuration. It needs a stable database target so the team can first make configuration, secret references, and validation boundaries clean.

## Decision

For Step 1, CPEmon keeps MySQL inside the EKS application boundary.

The current target is:

- MySQL runs in the `cpemon` namespace.
- Application workloads use `DB_DSN` from Kubernetes Secret `cpemon-db`, key `dsn`.
- MySQL container credentials use Kubernetes Secret `mysql-auth`.
- Real secret material should come from AWS Secrets Manager through External Secrets Operator in later subtasks of this story.
- RDS is documented as a future production hardening decision, not part of the immediate Step 1 implementation.

This keeps the database endpoint close to the existing MVP behavior while the platform team upgrades the packaging and secret-management model.

## Why Not RDS Immediately

Amazon RDS is the likely production direction for a managed relational database, but moving to RDS now would combine too many changes in one story:

- network reachability from EKS private subnets to RDS
- subnet group and security group design
- database parameter group decisions
- backup, snapshot, maintenance, and upgrade policy
- Terraform module design for RDS
- migration from in-cluster MySQL storage to managed storage
- credential rotation and application rollout behavior

Those are useful production topics, but they are not required to prove the first secret-management boundary.

The Step 1 migration goal is smaller and clearer:

```text
existing MySQL behavior -> reviewable Helm configuration -> External Secrets boundary -> later managed database hardening
```

## Alternatives

### Move to RDS Now

Pros:

- Better production operating model.
- Managed backups, maintenance windows, and database lifecycle.
- Cleaner separation between application pods and stateful database operations.

Cons:

- Adds AWS networking and database infrastructure scope before the application secret model is stable.
- Requires live AWS resources and may create cost.
- Makes local render validation less useful because the main proof becomes live infrastructure behavior.
- Blurs the interview story by mixing database migration, network design, and secret synchronization in one subtask.

### Use an External Interface/Port to Reach a Non-EKS MySQL

Pros:

- Can work for a lab or transitional environment.
- Avoids running the database inside the cluster.

Cons:

- Creates a less clean EKS target architecture.
- Requires manual endpoint and firewall handling.
- Does not teach the Kubernetes secret boundary as directly as an in-cluster service plus `DB_DSN` secret.

### Keep MySQL in EKS for Step 1

Pros:

- Preserves current application behavior.
- Keeps the migration scope focused.
- Lets Helm and ESO work be validated without redesigning the database layer.
- Keeps demo and interview explanation concrete.

Cons:

- In-cluster MySQL is not the final production posture for a serious environment.
- Persistence, backup, upgrades, failover, and storage performance remain weaker than a managed RDS design.
- A later migration plan is still needed.

## Consequences

Positive consequences:

- The team can finish secret management without waiting for RDS infrastructure.
- `DB_DSN` remains the application contract.
- Helm templates can reference stable Kubernetes Secret names and keys.
- External Secrets Operator can be introduced as a secret source without changing application code.
- The interview story stays layered and easy to defend.

Trade-offs:

- This is a Step 1 decision, not a final production database design.
- RDS migration is still an expected future hardening item.
- Live DB availability still depends on the in-cluster MySQL workload, PVC, and backup model.

## Interview Answer

I kept MySQL in EKS for Step 1 because I wanted to reduce migration variables. The project was already changing infrastructure, packaging, and secret delivery, so moving to RDS at the same time would mix several concerns. I treated RDS as the future production direction, but first stabilized the application contract: workloads read `DB_DSN` from a Kubernetes Secret, and that Secret can later be reconciled from AWS Secrets Manager through External Secrets Operator. That gives a clean path from the MVP to a production-grade model without doing every migration at once.
