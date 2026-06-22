# Argo CD CI/CD Separation Runbook

This runbook documents the deployment boundary introduced by Argo CD.

## Purpose

The platform now separates CI from CD:

```text
GitHub Actions -> test/build/publish image
Git           -> record desired Kubernetes state
Argo CD       -> compare Git with the cluster and sync manifests
Kubernetes    -> run the workloads
```

The important interview point is that Argo CD does not build CPEmon images.
It deploys the desired state that Git records.

## CI Responsibilities

CI owns the software artifact lifecycle:

* run unit tests and integration checks
* build `acs-ingest`, `cpemon-writer`, and `cpemon-api` images
* scan or validate images where the pipeline supports it
* publish immutable image tags to the container registry
* update Git with the promoted image tag or open a promotion pull request

CI should fail before Git desired state changes when tests, image build, or
image publish fails.

## Git Responsibilities

Git owns the desired deployment state:

* Helm chart source in `deploy/helm/cpemon`
* environment values such as `deploy/helm/cpemon/values-dev.yaml`
* Argo CD Applications under `k8s/gitops/dev/applications`
* platform add-on values and guardrail manifests
* review history for promotion, rollback, and drift explanation

The desired image tag should be visible in Git before Argo CD deploys it.

## Argo CD Responsibilities

Argo CD owns reconciliation:

* read the allowed Git and chart sources
* render Helm charts or plain manifests
* compare desired state with live cluster state
* report `Synced`, `OutOfSync`, `Healthy`, `Degraded`, or related states
* apply a manual sync when the operator approves it

In this story, sync remains manual and prune/self-heal remain disabled.

## Promotion Flow

Recommended dev promotion flow:

```text
developer merges code
        |
        v
CI tests and publishes image tag
        |
        v
promotion commit updates Helm values in Git
        |
        v
Argo CD shows diff
        |
        v
operator runs manual sync
        |
        v
Argo CD reconciles the cluster
```

For this learning repo, `values-dev.yaml` still contains a placeholder image
tag. A live GitOps deployment should replace that placeholder with an immutable
image tag produced by CI.

## Rollback Boundary

Rollback is also Git-first:

```powershell
git revert <promotion-commit>
argocd app sync cpemon-dev
argocd app wait cpemon-dev --sync --health --timeout 300
```

Do not roll back by rebuilding an old tag in place. Prefer immutable tags and
a Git change that points the deployment back to a known-good artifact.

## Common Mistakes

Avoid these explanations:

* "Argo CD builds and deploys the app."
* "CI deploys directly to Kubernetes."
* "GitOps means secrets are committed to Git."
* "Synced means the application is functionally healthy."

Better explanation:

> CI produces artifacts. Git records the desired deployment state. Argo CD
> reconciles Kubernetes to that reviewed desired state and reports drift.

## Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-ci-cd-separation.ps1
```

This validates that the runbook, knowledge notes, and interview notes preserve
the CI/CD boundary and do not imply that Argo CD builds images.
