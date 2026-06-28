# Crossplane Platform API Conventions

This document defines the CPEmon developer-facing Crossplane API contract.
Every XRD, Composition, and claim example in this repository should follow
these conventions unless a later ADR intentionally changes them.

## Design Goal

Developers should request approved infrastructure with a small, stable YAML
claim. The platform team keeps control of cloud provider details, IAM,
encryption, naming, deletion behavior, and operational defaults.

```text
Developer claim -> Crossplane XRD -> Composition -> AWS managed resource
```

## API Groups and Names

CPEmon platform APIs use:

```text
API group: platform.cpemon.io
Version:   v1alpha1
```

Composite kinds use the `XCPemon` prefix:

```text
XCPemonBucket
XCPemonDynamoTable
XCPemonECRRepository
```

Claim kinds omit the `X` prefix:

```text
CPemonBucketClaim
CPemonDynamoTableClaim
CPemonECRRepositoryClaim
```

## Required Claim Metadata

Every claim must include these labels:

```yaml
labels:
  app.kubernetes.io/name: cpemon-api
  app.kubernetes.io/part-of: cpemon
  cpemon.io/environment: dev
  cpemon.io/owner: platform
  cpemon.io/cost-center: learning
```

Every claim should include these annotations:

```yaml
annotations:
  cpemon.io/requested-by: platform-team
  cpemon.io/jira: CCPU-214
```

## Developer-Controlled Fields

Developers may set:

```yaml
spec:
  parameters:
    environment: dev
    owner: platform
    costCenter: learning
    region: eu-north-1
    resourceClass: standard
    deletionPolicy: Delete
```

Resource-specific fields are allowed when the platform API needs them, for
example bucket name suffixes, DynamoDB table keys, or ECR image tag mutability.

## Platform-Controlled Fields

Compositions control:

* providerConfigRef
* AWS account boundary
* encryption defaults
* private access defaults
* mandatory tags
* external names when needed
* connection secret names and namespaces
* unsafe provider-specific knobs

Developers should not set raw provider fields directly.

## Guardrails

The default guardrails are:

| Guardrail | Default |
| --- | --- |
| Environments | `dev`, `staging`, `prod` |
| Regions | `eu-north-1`, `eu-west-1`, `us-east-1` |
| Resource classes | `standard`, `critical` |
| Default deletion policy | `Delete` for dev, `Orphan` for production-like data |
| ProviderConfig | `aws-dev-irsa` |
| Required labels | app, owner, environment, cost center |
| GitOps mode | Pull request before claim sync |

## Interview Framing

The important interview point is that Crossplane is treated as a platform API,
not just a way to write AWS YAML in Kubernetes. The platform API is intentionally
small, opinionated, and validated before live AWS provisioning is claimed.
