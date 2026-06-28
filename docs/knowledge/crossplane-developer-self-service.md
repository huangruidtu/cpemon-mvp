# Crossplane Developer Self-Service Infrastructure Provisioning

This note captures the Step 2 Crossplane story for CPEmon.

The core idea is platform API design:

```text
developers request intent
platform engineers own implementation
GitOps reconciles the request
Crossplane provisions the cloud resource
```

## CCPU-216: Terraform and Crossplane Ownership Boundary

The first decision is ownership.

Terraform continues to own the foundation:

* VPC
* subnets
* EKS cluster
* node groups
* baseline IAM
* GitHub OIDC
* remote state
* foundational platform wiring

Crossplane owns selected application-level self-service resources:

* S3 bucket claims
* DynamoDB table claims
* optional ECR repository claims
* future queue, topic, database, or streaming claims

This split matters because Terraform and Crossplane both reconcile
infrastructure. They must not manage the same AWS resource.

## Why Not Replace Terraform

Crossplane is not introduced as a Terraform replacement in this project.

Terraform is better for the foundation because platform engineers need explicit
plans, module review, remote state, and controlled changes for high-blast-radius
resources.

Crossplane is better for developer enablement because it lets the platform team
expose a Kubernetes-native API for approved app-level resources.

## Mental Model

```text
Terraform = build the platform
Crossplane = expose selected platform capabilities
Argo CD = reconcile Git to the cluster
Kyverno = validate requests
OpenCost = observe cost after resources exist
```

## Interview Summary

Say this:

```text
I kept Terraform as the owner of the EKS foundation and introduced Crossplane as
a developer self-service layer for app-level resources. Developers submit
claims through GitOps, while the platform team controls XRDs, Compositions,
ProviderConfig, authentication, naming, labels, and deletion behavior.
```

Do not say this:

```text
Crossplane replaced Terraform.
Developers can create any AWS resource.
The story already proved live AWS provisioning.
```

The correct framing is:

```text
The framework and ownership model are implemented first. Live AWS provisioning
requires Crossplane, provider, IRSA, and an EKS cluster to be ready.
```

## CCPU-217: Crossplane GitOps Installation

Crossplane is installed as a GitOps-managed platform control-plane add-on:

```text
Application:   crossplane-dev
Namespace:     crossplane-system
Chart repo:    https://charts.crossplane.io/stable
Chart:         crossplane
Chart version: 2.3.2
Values file:   k8s/addons/crossplane/values.yaml
```

The installation is intentionally separated from provider configuration,
platform APIs, and developer claims:

```text
crossplane-dev -> provider config -> XRD/Composition -> developer claims
```

That ordering makes the control plane easier to troubleshoot. If Crossplane is
not healthy, provider and claim failures are noise.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-crossplane-installation.ps1
```

## CCPU-218: AWS Provider and IRSA Authentication Boundary

This task adds the AWS Provider configuration boundary:

```text
k8s/crossplane/providers/aws/provider-family-aws.yaml
k8s/crossplane/providers/aws/provider-services.yaml
k8s/crossplane/providers/aws/providerconfig.yaml
```

The provider path uses IRSA:

```text
Provider pod -> ServiceAccount annotation -> EKS OIDC -> AWS STS -> IAM role
```

The `ProviderConfig` uses:

```yaml
credentials:
  source: IRSA
```

This is safer than static AWS access keys because the provider receives
short-lived credentials from AWS instead of storing long-lived keys in a
Kubernetes Secret.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-aws-provider-irsa.ps1
```

Live validation requires the real IAM role ARN, EKS OIDC provider, trust policy,
provider pods, and an actual managed resource reconciliation.

## CCPU-219: Platform API Conventions and Guardrails

Before adding S3, DynamoDB, or ECR claims, the platform API contract is defined
in:

```text
k8s/crossplane/platform-api-conventions.md
ops/runbooks/crossplane-platform-api-conventions.md
```

The contract says developers submit small claims with approved fields:

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

The platform keeps control of `providerConfigRef`, encryption defaults, tags,
connection secrets, and unsafe provider-specific settings through XRDs and
Compositions.

This distinction is the heart of developer self-service:

```text
developers choose from an approved contract
platform engineers own the implementation behind that contract
```

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-platform-api-conventions.ps1
```

## CCPU-220: S3 Bucket XRD, Composition, and Developer Request

The first concrete platform API is an S3 bucket request:

```text
k8s/crossplane/functions/function-patch-and-transform.yaml
k8s/crossplane/platform-apis/s3/xrd.yaml
k8s/crossplane/platform-apis/s3/composition.yaml
k8s/crossplane/claims/dev/cpemon-api/s3-artifacts-bucket.yaml
```

The XRD uses Crossplane v2 with `scope: Namespaced`. That means the developer
request is a namespaced composite resource:

```yaml
apiVersion: platform.cpemon.io/v1alpha1
kind: XCPemonBucket
metadata:
  namespace: cpemon
spec:
  parameters:
    environment: dev
    owner: platform
    costCenter: learning
    region: eu-north-1
    resourceClass: standard
    deletionPolicy: Delete
    bucketNameSuffix: api-artifacts
```

In older Crossplane language this would often be called a claim. In Crossplane
v2, the safer interview wording is "namespaced composite resource request" or
"developer request."

The Composition maps the request to an AWS S3 `Bucket` through
`providerConfigRef: aws-dev-irsa`. Developers do not choose raw S3 provider
fields; the platform owns naming, tags, provider config, and composition
update policy.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-s3-bucket-platform-api.ps1
```

## CCPU-221: DynamoDB Table XRD, Composition, and Developer Request

The second concrete platform API is a DynamoDB table request:

```text
k8s/crossplane/platform-apis/dynamodb/xrd.yaml
k8s/crossplane/platform-apis/dynamodb/composition.yaml
k8s/crossplane/claims/dev/cpemon-api/dynamodb-health-table.yaml
```

The developer request keeps the API intentionally small:

```yaml
spec:
  parameters:
    environment: dev
    owner: platform
    costCenter: learning
    region: eu-north-1
    resourceClass: standard
    deletionPolicy: Delete
    tableNameSuffix: health-events
    partitionKey: healthId
    billingMode: PAY_PER_REQUEST
```

The first version only allows `PAY_PER_REQUEST`. That avoids premature capacity
tuning and is a reasonable default for a learning platform where traffic
patterns are not yet proven.

The Composition maps the request to an AWS DynamoDB `Table` through
`providerConfigRef: aws-dev-irsa`. Developers choose the partition key and
metadata; the platform controls provider auth, external name pattern, tags, and
composition behavior.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-dynamodb-table-platform-api.ps1
```

## CCPU-222: Optional ECR Repository Self-Service Extension

ECR is implemented as an optional platform API because it is small, useful for
developer delivery, and can be safely constrained:

```text
k8s/crossplane/platform-apis/ecr/xrd.yaml
k8s/crossplane/platform-apis/ecr/composition.yaml
k8s/crossplane/claims/dev/cpemon-api/ecr-image-repository.yaml
```

The API exposes only safe parameters:

```yaml
spec:
  parameters:
    environment: dev
    owner: platform
    costCenter: learning
    region: eu-north-1
    resourceClass: standard
    deletionPolicy: Delete
    repositoryNameSuffix: cpemon-api
    imageTagMutability: IMMUTABLE
    scanOnPush: true
```

The first version intentionally forces immutable image tags and scan-on-push.
That keeps ECR self-service aligned with platform security and release
traceability instead of becoming an unconstrained image registry request.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-ecr-repository-platform-api.ps1
```

## CCPU-223: Developer Self-Service Request Layout

The developer golden path is now documented and represented in the repository:

```text
k8s/crossplane/claims/README.md
k8s/crossplane/claims/dev/cpemon-api/README.md
k8s/crossplane/claims/dev/cpemon-api/kustomization.yaml
ops/runbooks/crossplane-developer-self-service-requests.md
```

The workflow is:

```text
edit request YAML -> open PR -> CI validation -> platform review -> merge -> Argo CD sync -> Crossplane reconcile
```

This is important because Crossplane self-service is not just an API design.
It also needs an operating model: folder ownership, review rules, validation,
and a clear boundary between developer intent and platform implementation.

The `cpemon-api` dev folder includes three request examples:

* S3 artifacts bucket
* DynamoDB health table
* ECR image repository

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-developer-requests.ps1
```

## CCPU-224: Argo CD Wiring for Crossplane

Crossplane is now represented as layered Argo CD Applications:

```text
crossplane-dev                 -> Crossplane controller
crossplane-providers-dev       -> providers, ProviderConfig, runtime config, functions
crossplane-platform-apis-dev   -> XRDs and Compositions
crossplane-claims-dev          -> cpemon-api developer requests
```

The ordering matters:

```text
controller -> providers/functions -> platform APIs -> developer requests
```

This keeps ownership clear. Platform engineers own provider and API layers.
Application teams own request intent. Argo CD gives each layer an observable
sync and health boundary.

Local validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-crossplane-wiring.ps1
```
