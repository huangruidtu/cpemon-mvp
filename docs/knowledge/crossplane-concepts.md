# Crossplane Concepts for CPEmon

This note explains the Crossplane terms used in the CPEmon developer
self-service story.

## Provider

A Provider installs Kubernetes CRDs and controllers for an external API such as
AWS. CPEmon uses AWS providers for S3, DynamoDB, and ECR.

## ProviderConfig

`ProviderConfig` tells provider-managed resources how to authenticate. CPEmon
uses `aws-dev-irsa`, which relies on IRSA instead of static AWS keys.

## XRD

`CompositeResourceDefinition` defines the platform API. In CPEmon:

* `XCPemonBucket`
* `XCPemonDynamoTable`
* `XCPemonECRRepository`

## Composition

A Composition maps the platform API to provider-managed resources. It hides raw
AWS provider fields and applies platform defaults.

## Composite Resource

In Crossplane v2, CPEmon developer requests are namespaced composite resources.
They live under `k8s/crossplane/claims` because developers experience them as
self-service claims, even though the object kind is `XCPemon...`.

## Managed Resource

A managed resource is the provider-level object, such as an AWS S3 Bucket,
DynamoDB Table, or ECR Repository.

## Connection Output

Connection outputs are values produced by reconciliation, such as bucket names,
table names, repository URLs, endpoints, or credentials. CPEmon documents the
shape but does not commit real generated secrets.

## GitOps Flow

```text
developer request -> PR -> validation -> platform review -> Argo CD -> Crossplane -> AWS
```

## Governance

Kyverno validates request metadata and safe parameter choices before Crossplane
reconciles a request. This keeps self-service from becoming unrestricted cloud
access.
