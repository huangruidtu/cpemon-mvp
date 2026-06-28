# Story 21 Interview Q&A: Crossplane Developer Self-Service

## Q1: What is the goal of this story?

The goal is to introduce Crossplane as a developer self-service infrastructure
layer. Developers should be able to request approved application-level cloud
resources through Kubernetes claims and GitOps pull requests, while the platform
team owns the provider configuration, XRDs, Compositions, guardrails, and
lifecycle behavior.

## Q2: What did CCPU-216 add?

It defined the Terraform and Crossplane ownership boundary. Terraform remains
responsible for the platform foundation, while Crossplane is introduced for
selected app-level self-service resources.

## Q3: What stays Terraform-owned?

VPC, subnets, EKS cluster, node groups, baseline IAM, GitHub OIDC, remote state,
cluster access, and foundational platform wiring stay Terraform-owned because
they are high-blast-radius resources that need explicit plan review.

## Q4: What can Crossplane own?

Crossplane can own selected app-level self-service resources such as S3 bucket
claims, DynamoDB table claims, optional ECR repository claims, and future queue
or topic claims once guardrails are in place.

## Q5: Why not replace Terraform with Crossplane?

Replacing Terraform would create unnecessary risk. Terraform is already the
foundation workflow for the EKS platform. Crossplane adds value as a platform
API for developers, not as a replacement for the foundational IaC model.

## Q6: What problem does the boundary prevent?

It prevents two control planes from managing the same AWS resource. If Terraform
and Crossplane both own the same resource, drift, rollback, and incident
ownership become unclear.

## Q7: How would you explain this in an interview?

I would say Terraform owns the platform foundation, and Crossplane exposes
selected app-level capabilities through safe Kubernetes APIs. Developers submit
claims through GitOps, while platform engineers own the abstractions and
guardrails.
