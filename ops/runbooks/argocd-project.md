# Argo CD CPEmon Project Runbook

This runbook covers `CCPU-97: Create Argo CD project for CPEmon`.

## Purpose

An Argo CD `AppProject` is a deployment guardrail. It defines which Git
repositories an Application can read from and which cluster destinations it can
deploy to.

For CPEmon, the learning project is:

```text
AppProject: cpemon
Namespace:  argocd
Repos:      CPEmon Git repo plus approved platform chart repositories
Targets:    cpemon, kafka, monitoring, external-secrets, security, platform
```

## Manifest

```text
k8s/addons/argocd/projects/cpemon-project.yaml
```

Apply it after Argo CD CRDs are installed:

```powershell
kubectl apply -f k8s/addons/argocd/projects/cpemon-project.yaml
```

## Verify

With kubectl:

```powershell
kubectl get appproject cpemon -n argocd
kubectl describe appproject cpemon -n argocd
```

With the Argo CD CLI:

```powershell
argocd proj get cpemon
```

## Learning Boundary

This project is intentionally broad enough for Story 11 because CPEmon manages
both application workloads and platform add-on boundaries in one learning repo.

Allowed namespaces:

* `cpemon`
* `kafka`
* `monitoring`
* `external-secrets`
* `security`
* `platform`

Allowed source repositories:

* `https://github.com/huangruidtu/cpemon-mvp.git`
* `registry-1.docker.io/bitnamicharts`
* `ghcr.io/prometheus-community/charts`
* `https://charts.external-secrets.io`

Allowed cluster-scoped resources are intentionally limited to the resource
types needed by platform add-on charts:

* `Namespace`
* `CustomResourceDefinition`
* `ClusterRole`
* `ClusterRoleBinding`
* `MutatingWebhookConfiguration`
* `ValidatingWebhookConfiguration`
* `APIService`

This keeps the learning project practical for operator-style add-ons without
making it fully cluster-admin by default.

## Production Hardening

For production, tighten this boundary:

* use environment-specific projects, such as `cpemon-dev` and `cpemon-prod`
* restrict namespaces per team or application
* restrict cluster-scoped resources aggressively
* use repository credentials and signed commits where appropriate
* configure Argo CD RBAC so not every user can sync every project
* consider a separate platform-admin project for CRDs, operators, and webhooks

## Troubleshooting

Application rejects with repository not permitted:
Check `spec.sourceRepos`.

Application rejects with destination not permitted:
Check `spec.destinations`.

Application needs CRDs or cluster-scoped resources:
Check `clusterResourceWhitelist` and decide whether that belongs in this
project or a separate platform-admin project.

Project manifest fails with unknown kind:
Argo CD CRDs are not installed yet. Complete the Argo CD installation first.

## Interview Explanation

An `AppProject` is not just a folder label. It is a security and ownership
boundary. It lets me say: this set of Applications can deploy only from these
repositories into these namespaces, and only these cluster-scoped resource
types are allowed. That makes the GitOps model safer and easier to explain than
giving every Application unrestricted cluster access.
