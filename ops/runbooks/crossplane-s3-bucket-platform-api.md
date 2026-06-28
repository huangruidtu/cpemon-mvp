# Crossplane S3 Bucket Platform API Runbook

This runbook covers the CPEmon S3 bucket self-service API.

## What Was Added

```text
k8s/crossplane/functions/function-patch-and-transform.yaml
k8s/crossplane/platform-apis/s3/xrd.yaml
k8s/crossplane/platform-apis/s3/composition.yaml
k8s/crossplane/claims/dev/cpemon-api/s3-artifacts-bucket.yaml
```

The XRD creates a namespaced platform API:

```text
apiVersion: platform.cpemon.io/v1alpha1
kind: XCPemonBucket
```

The developer-facing example is stored under `k8s/crossplane/claims` because it
is the self-service request. In Crossplane v2 this is a namespaced composite resource rather than the older v1 claim object.

## Developer Request

Developers set only approved parameters:

```yaml
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

The platform controls:

* AWS provider config: `aws-dev-irsa`
* full external bucket name pattern
* mandatory tags
* deletion policy enum
* region enum
* composition revision behavior

## Live Validation

After Crossplane, the AWS provider, IRSA, and the patch-and-transform function
are healthy:

```powershell
kubectl apply -f k8s/crossplane/functions/function-patch-and-transform.yaml
kubectl apply -f k8s/crossplane/platform-apis/s3/xrd.yaml
kubectl apply -f k8s/crossplane/platform-apis/s3/composition.yaml
kubectl apply -f k8s/crossplane/claims/dev/cpemon-api/s3-artifacts-bucket.yaml
kubectl get xcpemonbuckets.platform.cpemon.io -n cpemon
kubectl describe xcpemonbucket.platform.cpemon.io -n cpemon cpemon-api-artifacts
```

## Rollback

For dev examples, delete the request first:

```powershell
kubectl delete -f k8s/crossplane/claims/dev/cpemon-api/s3-artifacts-bucket.yaml
```

For production-like data, prefer `deletionPolicy: Orphan` and verify ownership
before deleting the composed AWS resource.

## Interview Answer

Say:

```text
I exposed S3 as a small Crossplane platform API. Developers choose environment,
owner, cost center, region, class, deletion policy, and a name suffix. The
Composition maps that request to an AWS S3 Bucket using the IRSA-backed
ProviderConfig and platform-owned tags.
```
