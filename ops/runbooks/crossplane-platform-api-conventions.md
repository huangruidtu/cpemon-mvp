# Crossplane Platform API Conventions Runbook

This runbook explains the developer-facing API contract for CPEmon Crossplane
claims.

## Purpose

Before creating S3, DynamoDB, or ECR abstractions, the platform needs a stable
contract:

```text
small developer claim -> platform-owned XRD -> platform-owned Composition
```

That contract avoids accidental exposure of raw AWS provider fields and gives
the platform team a consistent policy surface.

## Files

```text
k8s/crossplane/platform-api-conventions.md
docs/knowledge/crossplane-developer-self-service.md
docs/knowledge/interview/story-21-crossplane-developer-self-service.md
```

## Required Claim Shape

Every CPEmon claim should carry standard ownership, environment, and cost
metadata:

```yaml
metadata:
  labels:
    app.kubernetes.io/part-of: cpemon
    cpemon.io/environment: dev
    cpemon.io/owner: platform
    cpemon.io/cost-center: learning
spec:
  parameters:
    environment: dev
    owner: platform
    costCenter: learning
    region: eu-north-1
    resourceClass: standard
    deletionPolicy: Delete
```

## Platform Ownership

The platform team owns:

* XRD schemas
* Compositions
* ProviderConfig references
* encryption defaults
* required tags and labels
* deletion behavior defaults
* connection secret conventions

Developers own:

* claim pull requests
* business ownership labels
* environment selection
* approved resource class selection

## Offline Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-platform-api-conventions.ps1
```

The script checks that the API contract, learning notes, interview notes, README
index, and Makefile target stay wired together.

## Live Validation Boundary

This task does not create AWS resources. Live validation starts after concrete
XRDs, Compositions, claims, Argo CD Applications, Crossplane providers, and IRSA
are healthy in a real EKS cluster.

## Interview Answer

Say:

```text
I defined the platform API before exposing resource claims. Developers get a
small claim contract with environment, owner, cost center, region, resource
class, and deletion policy. The platform owns the provider details and default
security behavior through XRDs and Compositions.
```

Avoid saying:

```text
Developers can configure any AWS provider field.
```
