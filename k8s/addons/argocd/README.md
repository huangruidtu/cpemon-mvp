# Argo CD Add-on

This directory documents the Step 1 Argo CD installation boundary for the
CPEmon learning environment.

Argo CD is installed into the `argocd` namespace. The namespace already exists
in `k8s/base/namespaces.yaml`; this directory keeps the add-on-specific
namespace manifest close to the Argo CD runbook so the installation boundary is
easy to find.

## Learning Install

For the current learning environment, install Argo CD from the upstream stable
manifest:

```powershell
kubectl apply -f k8s/addons/argocd/namespace.yaml
kubectl apply -n argocd --server-side --force-conflicts `
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

The upstream documentation recommends pinning a version for production. The
`stable` URL is acceptable here because this story is a learning-path install
and the repository records the operational boundary in the runbook.

## Verify

```powershell
kubectl get pods -n argocd
kubectl get deploy -n argocd
kubectl get svc -n argocd
```

Expected control-plane components include:

* `argocd-server`
* `argocd-repo-server`
* `argocd-application-controller`
* `argocd-applicationset-controller`
* `argocd-redis`
* `argocd-dex-server`

## Access

Use port-forwarding for the learning environment:

```powershell
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Then open:

```text
https://localhost:8080
```

The `argocd` CLI is helpful but not required for the repository-level checks.
Later tasks that need CLI login should stop and install the CLI if it is not on
`PATH`.

