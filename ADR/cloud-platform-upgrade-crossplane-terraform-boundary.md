# ADR: Terraform and Crossplane Ownership Boundary

## Status

Accepted

## Context

The CPEmon platform already uses Terraform for the cloud foundation and GitOps
for Kubernetes workloads and platform add-ons.

Crossplane is being introduced in Step 2 as a developer self-service
infrastructure layer. It should not replace the Terraform foundation. It should
expose a small platform API for safe, repeatable, application-level resource
requests.

Without a clear boundary, the platform would have two provisioning systems
competing for the same AWS resources. That would create ownership confusion,
state drift, incident ambiguity, and harder interviews.

## Decision

Terraform remains the owner of foundational infrastructure.

Crossplane owns selected application-level self-service resources.

## Terraform-Owned Foundation

Terraform owns resources that define the platform substrate:

* VPC and subnet topology
* EKS cluster and managed node groups
* cluster access entries and baseline IAM
* GitHub OIDC and CI/CD AWS roles
* foundational IRSA roles
* remote state and state locking
* account-level or network-level wiring
* bootstrap path for Argo CD and shared platform add-ons

These resources are high-blast-radius and should stay in Terraform because
Terraform gives explicit plans, state review, module structure, and a familiar
foundation workflow.

## Crossplane-Owned Self-Service

Crossplane may own resources requested by application teams through a platform
API:

* S3 bucket claims
* DynamoDB table claims
* optional ECR repository claims
* future SQS or SNS claims
* future RDS or MSK-related claims after stronger guardrails exist

These resources are exposed as Kubernetes custom resources such as Claims,
backed by platform-owned XRDs and Compositions.

## Control Model

Developers should not edit low-level AWS provider resources directly.

The developer path is:

```text
developer claim YAML -> Argo CD -> Crossplane claim -> Composition -> AWS managed resource
```

The platform team owns:

* Provider packages
* ProviderConfig and authentication
* XRD schema
* Composition templates
* allowed fields
* naming rules
* labels and cost metadata
* deletion policy
* validation scripts and runbooks

Developers own:

* claim intent
* application name
* environment
* owner metadata
* approved size or class choices
* pull request context

## Non-Goals

This boundary does not:

* migrate EKS or VPC resources from Terraform to Crossplane
* give developers direct access to arbitrary AWS resources
* remove Terraform plan review for platform foundation changes
* claim live AWS provisioning before IRSA and provider credentials are tested
* implement a full internal developer portal

## Consequences

Positive:

* Terraform keeps clear ownership of high-blast-radius resources.
* Crossplane can focus on developer enablement.
* Developers get a Kubernetes-native request path.
* GitOps remains the reconciliation entry point.
* The platform team can add guardrails before exposing new resource classes.

Tradeoffs:

* The platform must operate two provisioning models.
* Documentation must clearly separate foundation changes from app-level claims.
* Some resources, such as ECR repositories, may reasonably fit either model and
  need explicit decisions.
* Live validation needs AWS, EKS, IRSA, and Crossplane provider readiness.

## Interview Answer

```text
I kept Terraform responsible for foundational infrastructure like VPC, EKS, IAM
baseline, OIDC, and node groups. I introduced Crossplane only for selected
application-level self-service resources such as S3 buckets and DynamoDB
tables. That avoids competing state ownership while still giving developers a
GitOps-based infrastructure request workflow.
```
