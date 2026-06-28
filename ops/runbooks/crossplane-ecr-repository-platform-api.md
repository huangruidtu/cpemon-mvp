# Crossplane ECR Repository Platform API Runbook

This runbook covers the optional CPEmon ECR repository self-service extension.

## Decision

ECR is implemented as a small optional platform API because it is close to the
developer delivery workflow and can be safely constrained:

```text
k8s/crossplane/platform-apis/ecr/xrd.yaml
k8s/crossplane/platform-apis/ecr/composition.yaml
k8s/crossplane/claims/dev/cpemon-api/ecr-image-repository.yaml
```

## Guardrails

The first ECR API version keeps these defaults:

* `imageTagMutability: IMMUTABLE`
* `scanOnPush: true`
* approved region enum
* required owner and cost center metadata
* platform-owned provider config: `aws-dev-irsa`
* platform-owned external repository naming

This prevents the self-service path from becoming a raw ECR provider escape
hatch.

## Developer Request

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

## Live Validation

```powershell
kubectl apply -f k8s/crossplane/platform-apis/ecr/xrd.yaml
kubectl apply -f k8s/crossplane/platform-apis/ecr/composition.yaml
kubectl apply -f k8s/crossplane/claims/dev/cpemon-api/ecr-image-repository.yaml
kubectl get xcpemonecrrepositories.platform.cpemon.io -n cpemon
kubectl describe xcpemonecrrepository.platform.cpemon.io -n cpemon cpemon-api-images
```

## Interview Answer

Say:

```text
I added ECR as an optional Crossplane self-service extension, but kept the API
narrow. Developers can request an approved repository, while the platform
forces immutable tags, scan-on-push, required cost metadata, and the IRSA-backed
provider boundary.
```
