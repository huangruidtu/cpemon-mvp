# ADR: External Secrets Operator with AWS Secrets Manager and KMS

## Status

Accepted for Step 1 secret-management design.

## Context

CPEmon now deploys its application workloads through Helm and raw Kubernetes manifests that reference runtime Secrets:

- `cpemon-db`, key `dsn`
- `cpemon-acs-hmac`, key `hmac-secret`
- `mysql-auth`, keys `mysql-root-password`, `mysql-username`, `mysql-password`, `mysql-database`

The current Git repository documents the expected Kubernetes Secret names and keys, but it must not contain the real secret values.

The next platform question is:

```text
Where should real secret material live, and how should it enter the cluster?
```

## Decision

Use this model for CPEmon Step 1:

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

Git owns:

- `SecretStore` or `ClusterSecretStore` manifests
- `ExternalSecret` manifests
- Kubernetes Secret names and keys
- workload `secretKeyRef` wiring
- documentation and validation scripts

Git does not own:

- database passwords
- HMAC secrets
- AWS access keys
- decoded Kubernetes Secret values
- `.env` files containing production credentials

AWS Secrets Manager owns the real secret values.

AWS KMS protects the Secrets Manager secret values at rest.

IRSA gives the External Secrets Operator controller AWS permissions without static AWS credentials in the cluster.

## Why External Secrets Operator

External Secrets Operator fits this project because it turns secret delivery into a Kubernetes reconciliation problem:

```text
desired ExternalSecret manifest in Git
        |
        v
operator reconciles against AWS Secrets Manager
        |
        v
Kubernetes Secret appears for the workload
```

That works well with Helm and GitOps because the application chart can keep referencing normal Kubernetes Secrets, while the actual values stay outside Git.

## Why AWS Secrets Manager

AWS Secrets Manager is selected because CPEmon is moving to EKS on AWS, and the future production path likely includes RDS, service credentials, HMAC material, and possibly third-party tokens.

Secrets Manager gives a clear managed boundary for:

- central secret storage
- IAM-based access control
- auditability through AWS APIs and CloudTrail
- optional rotation workflows later
- integration with AWS KMS

## Why KMS

Secrets Manager uses AWS KMS in its encryption model. The project can begin with the AWS managed key for Secrets Manager in a dev account, then move to a customer managed KMS key when production needs tighter key policy, audit, and separation-of-duties control.

For interview purposes, the important distinction is:

```text
Secrets Manager stores and versions the secret.
KMS protects the cryptographic key material used to encrypt it.
IAM controls who can read or manage it.
ESO syncs an allowed subset into Kubernetes.
```

## Why IRSA

External Secrets Operator needs AWS API permissions such as reading specific Secrets Manager secrets.

Do not give ESO static AWS keys in a Kubernetes Secret.

Use IRSA so the ESO Kubernetes service account can assume a narrowly scoped IAM role. This creates a stronger trust chain:

```text
EKS OIDC provider
        |
        v
Kubernetes service account
        |
        v
IAM role trust policy
        |
        v
secretsmanager:GetSecretValue for approved secret ARNs
```

## Deferred Decisions

RDS credentials are not implemented in this subtask because CCPU-61 intentionally keeps MySQL in the EKS application boundary for Step 1. The same `cpemon-db/dsn` Secret contract will support RDS later.

Kafka credentials are not implemented in this subtask because Kafka is outside the current CPEmon MVP runtime path. The same ESO pattern can be reused when Kafka is introduced.

Secret rotation is not implemented in this subtask. Rotation requires application behavior decisions, reload behavior, database user strategy, and operational runbooks.

## Consequences

Positive:

- Real secret values stay outside Git.
- Workloads keep using standard Kubernetes `secretKeyRef`.
- Helm values do not need to contain credentials.
- Secret access can be scoped with IAM and secret ARNs.
- The pattern is reusable for DB, HMAC, future RDS, and future Kafka credentials.

Trade-offs:

- ESO introduces another controller and CRDs to install and operate.
- Secret delivery now depends on AWS API access, IAM policy, KMS policy, and Kubernetes reconciliation.
- Local clusters need either a different provider, a bootstrap Secret, or a mock path.
- Live validation requires `kubectl`, a cluster, ESO installed, AWS permissions, and real AWS secrets.

## Validation Boundary

This ADR validates the architecture decision, not a live ESO sync.

Live validation belongs to later subtasks:

- create the IRSA and IAM/KMS contract
- template `SecretStore` or `ClusterSecretStore`
- template `ExternalSecret` resources
- validate local render boundaries
- run live sync checks when `kubectl`, kubeconfig, and AWS resources exist

## Interview Answer

I did not put passwords in Helm values or Git. I chose External Secrets Operator because it lets Git define the desired Kubernetes Secret contract while AWS Secrets Manager remains the source of truth for real secret values. KMS protects the encrypted secret material at rest, and IRSA lets the ESO controller read only approved secrets without static AWS keys. The application still consumes normal Kubernetes Secrets through `secretKeyRef`, so the app code and Helm chart stay stable while the secret source becomes production-grade.

## References

- External Secrets Operator AWS Secrets Manager provider documentation: https://external-secrets.io/latest/provider/aws-secrets-manager/
- AWS Secrets Manager encryption and decryption documentation: https://docs.aws.amazon.com/secretsmanager/latest/userguide/security-encryption.html
- Amazon EKS IAM roles for service accounts documentation: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
