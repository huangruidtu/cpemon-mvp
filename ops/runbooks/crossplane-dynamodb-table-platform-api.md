# Crossplane DynamoDB Table Platform API Runbook

This runbook covers the CPEmon DynamoDB table self-service API.

## What Was Added

```text
k8s/crossplane/platform-apis/dynamodb/xrd.yaml
k8s/crossplane/platform-apis/dynamodb/composition.yaml
k8s/crossplane/claims/dev/cpemon-api/dynamodb-health-table.yaml
```

The XRD creates a namespaced platform API:

```text
apiVersion: platform.cpemon.io/v1alpha1
kind: XCPemonDynamoTable
```

The developer request is intentionally small. It exposes a table suffix,
partition key, billing mode, region, owner, cost center, resource class, and
deletion policy. The platform owns provider configuration, tags, and the
composition implementation.

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
    tableNameSuffix: health-events
    partitionKey: healthId
    billingMode: PAY_PER_REQUEST
```

`PAY_PER_REQUEST` is the only allowed billing mode in this first version. That
keeps the learning platform simple and avoids provisioning throughput tuning
before there is real workload evidence.

## Live Validation

After Crossplane, the AWS provider, IRSA, and the patch-and-transform function
are healthy:

```powershell
kubectl apply -f k8s/crossplane/platform-apis/dynamodb/xrd.yaml
kubectl apply -f k8s/crossplane/platform-apis/dynamodb/composition.yaml
kubectl apply -f k8s/crossplane/claims/dev/cpemon-api/dynamodb-health-table.yaml
kubectl get xcpemondynamotables.platform.cpemon.io -n cpemon
kubectl describe xcpemondynamotable.platform.cpemon.io -n cpemon cpemon-api-health-events
```

## Rollback

For dev examples:

```powershell
kubectl delete -f k8s/crossplane/claims/dev/cpemon-api/dynamodb-health-table.yaml
```

For production-like data, use `deletionPolicy: Orphan` and verify table
ownership before deleting the composed AWS resource.

## Interview Answer

Say:

```text
I exposed DynamoDB through a namespaced Crossplane platform API. Developers
choose the partition key and approved metadata, but the platform controls the
provider, tags, naming convention, and safe default billing mode.
```
