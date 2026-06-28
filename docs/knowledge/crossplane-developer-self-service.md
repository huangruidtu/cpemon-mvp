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
