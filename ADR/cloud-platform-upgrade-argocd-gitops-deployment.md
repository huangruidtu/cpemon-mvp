# ADR: Argo CD GitOps Deployment for CPEmon

## Status

Accepted for Story 11 implementation.

## Context

CPEmon now has three important cloud-platform building blocks:

* Terraform creates the AWS/EKS foundation.
* Helm renders CPEmon Kubernetes manifests.
* GitHub Actions is the CI boundary for tests, builds, and image publishing.

The project needs a deployment control plane that can keep the EKS cluster
aligned with the desired state in Git without letting CI mutate the cluster
directly.

## Decision

Use Argo CD as the GitOps deployment controller for CPEmon.

The initial implementation uses:

* namespace `argocd`
* AppProject `cpemon`
* manual sync
* prune disabled
* self-heal disabled
* plain Application manifests in `k8s/gitops/dev/applications`
* CPEmon chart source from `deploy/helm/cpemon`
* external Helm charts for Kafka, monitoring, and External Secrets
* staged NetworkPolicy manifests for policy/security

## Rationale

Argo CD fits this project because it makes deployment state reviewable:

```text
Git desired state -> Argo CD diff/sync -> Kubernetes cluster
```

It also gives the project an interview-ready separation of responsibilities:

* CI produces tested image artifacts.
* Git records the desired deployment state.
* Argo CD reconciles the cluster to Git.
* Kubernetes runs the workloads.

## Alternatives Considered

### GitHub Actions Applies Directly

This is simpler but blurs CI and CD. The pipeline would need broad cluster
credentials, and drift detection would be weaker because the cluster would not
have a controller continuously comparing live state with Git.

### Flux CD

Flux is a valid GitOps option. Argo CD was selected here because its
Application/AppProject model, UI, CLI, and diff workflow are easy to explain in
an interview and map clearly to the CPEmon learning goals.

### Helmfile Or Manual Helm

Manual Helm can install the chart, but it does not provide the same
controller-driven drift detection, Application health, or Git-backed sync
workflow.

## Consequences

Positive:

* Git becomes the deployment source of truth.
* Application diffs are visible before manual sync.
* Drift can be detected and reconciled.
* AppProject boundaries limit allowed sources and destinations.
* Rollback can be expressed as a Git revert plus Argo CD sync.

Tradeoffs:

* Argo CD is another controller to operate.
* AppProject permissions must be maintained as Applications add chart repos,
  namespaces, and cluster-scoped resources.
* CRD ordering matters for monitoring and External Secrets.
* Live validation requires a reachable cluster API and Argo CD CRDs.
* Manual sync adds an operational step until automation is intentionally
  approved.

## Deferred Hardening

Deferred production work:

* pin and review Argo CD installation manifests
* configure SSO, RBAC, TLS, and ingress
* split AppProjects by environment or team
* move from `HEAD` to explicit environment revisions where appropriate
* define automated sync policy per Application
* test prune and self-heal safely before enabling them
* backup Argo CD configuration and document disaster recovery
* add notifications for sync failures and degraded Applications

## Rollout

1. Install Argo CD in `argocd`.
2. Apply the `cpemon` AppProject.
3. Apply dev Application manifests.
4. Inspect diffs.
5. Sync platform dependencies before CPEmon workloads.
6. Validate application health and dependency readiness.

## Rollback

Use Git-first rollback:

```powershell
git revert <bad-promotion-commit>
argocd app sync cpemon-dev
argocd app wait cpemon-dev --sync --health --timeout 300
```

For platform add-ons, review CRDs, PVCs, StatefulSets, and chart release notes
before rollback.

## Operational References

* `ops/runbooks/argocd-operations.md`
* `ops/runbooks/argocd-installation.md`
* `ops/runbooks/argocd-project.md`
* `ops/runbooks/argocd-gitops-layout.md`
* `ops/runbooks/argocd-sync-policy.md`
* `ops/runbooks/argocd-prune-self-heal-guardrails.md`
* `ops/runbooks/argocd-gitops-deployment-validation.md`
* `ops/runbooks/argocd-drift-detection-validation.md`
* `ops/runbooks/argocd-ci-cd-separation.md`
* `docs/knowledge/argocd-gitops-deployment.md`
* `docs/knowledge/interview/story-17-argocd-gitops-deployment.md`

## Interview Answer

I introduced Argo CD after Terraform and Helm. Terraform creates the EKS
foundation, Helm defines how CPEmon renders into Kubernetes, and Argo CD makes
Git the deployment source of truth. I kept sync manual and disabled prune and
self-heal at first because the platform includes stateful add-ons, CRDs,
External Secrets, and NetworkPolicy guardrails. That gave me drift detection
and reviewable deployment without pretending the first GitOps step was already
production-hardened.
