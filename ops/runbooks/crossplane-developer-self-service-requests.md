# Crossplane Developer Self-Service Requests Runbook

This runbook explains the CPEmon developer golden path for infrastructure
requests.

## Folder Layout

```text
k8s/crossplane/claims/dev/cpemon-api/
  README.md
  kustomization.yaml
  s3-artifacts-bucket.yaml
  dynamodb-health-table.yaml
  ecr-image-repository.yaml
```

Each application/environment pair gets its own folder. That keeps ownership,
review, and future Argo CD wiring easy to reason about.

## Request Lifecycle

```text
Developer edits request YAML
-> Pull request
-> CI/offline validation
-> Platform review
-> Merge
-> Argo CD sync
-> Crossplane reconciliation
-> AWS resource ready
```

## Reviewer Responsibilities

Platform reviewers check:

* approved API version and kind
* namespace and application ownership
* owner and cost center labels
* environment and region
* deletion policy
* resource class
* whether the request maps to an approved XRD and Composition

## Developer Responsibilities

Developers provide:

* business intent
* application namespace
* environment
* owner and cost center
* resource-specific suffix or key fields

They do not edit ProviderConfig, IAM roles, Compositions, or raw AWS provider
fields.

## Interview Answer

Say:

```text
I created a golden path where app teams request infrastructure through
application/environment folders in Git. CI validates the request shape, platform
reviewers check ownership and safety, then Argo CD and Crossplane reconcile it.
That turns infrastructure into a controlled developer workflow instead of a
manual ticket queue.
```
