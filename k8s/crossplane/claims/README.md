# Crossplane Developer Requests

This directory is the developer-facing self-service area for CPEmon
infrastructure requests.

In Crossplane v2, the request objects are namespaced composite resources. The
directory keeps the familiar `claims` name because application teams experience
these files as infrastructure claims submitted through GitOps.

## Layout

```text
claims/
  dev/
    cpemon-api/
      kustomization.yaml
      README.md
      s3-artifacts-bucket.yaml
      dynamodb-health-table.yaml
      ecr-image-repository.yaml
```

## Pull Request Workflow

1. Developer adds or edits a request under the application/environment folder.
2. CI runs offline validation scripts.
3. Platform reviewer checks owner, cost center, environment, deletion policy,
   region, resource class, and whether the request fits the approved XRD.
4. Argo CD reconciles the request only after merge.
5. Crossplane reconciles the namespaced request into provider-managed AWS
   resources.

## Reviewer Checklist

* Does the request use `platform.cpemon.io/v1alpha1`?
* Is the namespace correct for the app?
* Are owner and cost center labels present?
* Is `deletionPolicy` appropriate for the data type?
* Is the region approved?
* Is the resource class justified?
* Is the resource covered by a platform-owned XRD and Composition?
