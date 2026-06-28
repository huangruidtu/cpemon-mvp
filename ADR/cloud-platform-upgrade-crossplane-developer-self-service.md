# ADR: Crossplane Developer Self-Service Platform API

## Status

Accepted

## Context

CPEmon already uses Terraform for foundational AWS and EKS infrastructure. That
foundation includes high-blast-radius resources such as VPC, subnets, EKS,
node groups, IAM, remote state, and platform add-ons.

Developer teams still need a safer way to request application-level resources
without opening manual infrastructure tickets for every S3 bucket, DynamoDB
table, or image repository.

## Decision

Use Crossplane as a Kubernetes-native platform API layer for selected
application-level self-service resources.

Terraform remains the owner of the foundation. Crossplane owns approved
developer-facing abstractions:

* `XCPemonBucket`
* `XCPemonDynamoTable`
* `XCPemonECRRepository`

Developers submit requests through GitOps. Platform engineers own providers,
ProviderConfig, IRSA, XRDs, Compositions, policy guardrails, lifecycle rules,
and live validation.

## Consequences

Positive:

* application teams get a clear self-service workflow
* platform engineers keep control of provider details and defaults
* Argo CD provides reviewable GitOps reconciliation
* Kyverno enforces request guardrails
* offline validation can prove repository consistency without AWS credentials

Tradeoffs:

* Crossplane adds another control plane to operate
* live validation still requires EKS, IRSA, providers, and AWS permissions
* Terraform and Crossplane ownership must remain explicit to avoid drift
* XRD and Composition versions become platform APIs and need lifecycle care

## Non-Goals

This decision does not replace Terraform.

This decision does not grant developers raw AWS provider access.

This decision does not claim live AWS provisioning until a cluster, providers,
IRSA, and resource reconciliation are validated.

## Interview Summary

```text
I kept Terraform for the platform foundation and used Crossplane to expose a
small Kubernetes-native platform API for app-level resources. Developers submit
GitOps requests, while the platform owns providers, auth, schemas,
Compositions, guardrails, lifecycle, and validation.
```
