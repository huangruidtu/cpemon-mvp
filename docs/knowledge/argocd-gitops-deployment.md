# Argo CD GitOps Deployment

Story 11 introduces Argo CD as the GitOps controller for CPEmon.

## Why Argo CD

Before this story, the upgrade has infrastructure and packaging pieces:

```text
Terraform -> EKS and AWS foundation
Helm      -> CPEmon application templates
kubectl   -> manual apply and validation
```

Argo CD adds the deployment control plane:

```text
Git desired state -> Argo CD -> Kubernetes cluster
```

This is the CI/CD separation:

* CI builds, tests, and publishes images.
* Git records the desired deployment state.
* Argo CD reconciles the cluster to that desired state.

## CCPU-96: Install Argo CD

The first subtask establishes the Argo CD control plane in the `argocd`
namespace.

Learning install:

```powershell
kubectl apply -f k8s/addons/argocd/namespace.yaml
kubectl apply -n argocd --server-side --force-conflicts `
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Why this is acceptable for Step 1:

* It follows the official quick-start shape.
* It gets the GitOps controller running quickly.
* It avoids mixing controller installation with CPEmon Application design.
* The production hardening path is documented separately.

Production difference:

For production, pin the Argo CD version, review manifests, configure SSO/RBAC,
secure ingress/TLS, and define an upgrade/backup plan.

## Verification

```powershell
kubectl get ns argocd
kubectl get pods -n argocd
kubectl get deploy -n argocd
kubectl get svc -n argocd
```

For local UI access:

```powershell
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

## Interview Framing

Do not say "Argo CD builds and deploys my app." A stronger answer is:

> GitHub Actions owns CI: tests, builds, and image publishing. Git owns desired
> state. Argo CD owns CD: it watches Git, compares desired state with live
> cluster state, and reconciles drift.

## CCPU-97: Create Argo CD Project

The `cpemon` AppProject defines the first GitOps guardrail.

Manifest:

```text
k8s/addons/argocd/projects/cpemon-project.yaml
```

It allows Argo CD Applications in the `cpemon` project to read from the source
repository:

```text
https://github.com/huangruidtu/cpemon-mvp.git
```

It allows deployment to the learning target namespaces:

* `cpemon`
* `kafka`
* `monitoring`
* `security`
* `platform`

Why this matters:

An AppProject is a security and ownership boundary. It prevents the story from
accidentally teaching "Argo CD can deploy anything anywhere." Instead, the
project records which repository and target namespaces are allowed.

Production hardening:

The learning project is intentionally broad. A production platform should split
projects by environment or team, restrict cluster-scoped resources, and pair
the project with Argo CD RBAC.
