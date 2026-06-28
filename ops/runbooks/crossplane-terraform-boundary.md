# Crossplane and Terraform Boundary Runbook

This runbook explains the operating boundary between Terraform and Crossplane
for the CPEmon platform.

Use it before adding any new Crossplane resource type.

## Boundary Summary

```text
Terraform  -> platform foundation
Crossplane -> application-level self-service resources
Argo CD    -> GitOps reconciliation entry point
Kyverno    -> request guardrails
OpenCost   -> cost visibility after resources exist
```

## Terraform Owns

Terraform owns the resources that make the platform exist:

* VPC
* public and private subnets
* EKS cluster
* managed node groups
* cluster access entries
* IAM baseline
* GitHub OIDC role for CI/CD
* remote state backend
* foundational IRSA roles

Operational rule:

```text
If changing it can break the cluster foundation, keep it in Terraform.
```

## Crossplane Owns

Crossplane owns selected app-level infrastructure requests:

* S3 bucket claim
* DynamoDB table claim
* optional ECR repository claim
* future queue, topic, database, or streaming claims after review

Operational rule:

```text
If a developer can request it through a safe platform API, Crossplane can own it.
```

## Before Adding A New Claim Type

Ask:

1. Is this resource app-level, not platform-foundational?
2. Can the platform hide low-level AWS complexity?
3. Can the allowed fields be small and safe?
4. Can labels and cost metadata be required?
5. Can deletion behavior be documented?
6. Can the resource be validated offline before live AWS provisioning?
7. Can the live validation be run without console-only steps?

If the answer is no, keep the resource in Terraform or defer it.

## GitOps Flow

```text
developer PR
  -> claim YAML
  -> platform review
  -> Argo CD sync
  -> Crossplane reconcile
  -> AWS resource
  -> application config or connection output
```

## Live Validation Boundary

Do not claim Crossplane created real AWS resources unless all of these are true:

* Crossplane is installed and healthy.
* AWS Provider is installed and healthy.
* ProviderConfig is ready.
* IRSA trust policy is configured.
* Argo CD synced the claim.
* Crossplane reports Ready.
* The AWS resource is visible through AWS CLI or console.

Offline validation may prove only:

* file layout
* YAML structure
* GitOps Application wiring
* XRD and Composition intent
* claim examples
* documentation links

## Troubleshooting Ownership

If Terraform plan shows drift for a Crossplane-owned resource:

```text
Wrong ownership boundary. Remove the resource from one control plane.
```

If Crossplane tries to create foundational platform resources:

```text
Wrong abstraction. Move it back to Terraform or create a separate architecture decision.
```

If developers need raw AWS provider fields:

```text
The platform API is too thin. Improve the Composition instead of exposing raw provider complexity.
```

## Interview Notes

The concise explanation:

```text
Terraform owns the platform foundation because it has high blast radius and
needs explicit plan review. Crossplane owns selected self-service resources
because developers need a safe GitOps way to request app-level infrastructure.
The boundary prevents two tools from managing the same AWS resource.
```
