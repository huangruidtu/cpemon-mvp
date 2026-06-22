# Argo CD Kyverno Installation Runbook

This runbook validates the `kyverno-dev` Argo CD Application.

## Application Contract

```text
Application:    kyverno-dev
Project:        cpemon
Chart repo:     https://kyverno.github.io/kyverno/
Chart:          kyverno
Chart version:  3.8.1
App version:    v1.18.1
Release name:   kyverno
Values source:  https://github.com/huangruidtu/cpemon-mvp.git
Values file:    k8s/addons/kyverno/values.yaml
Destination:    https://kubernetes.default.svc / kyverno
Sync policy:    manual
```

Kyverno is installed as platform governance infrastructure. Application teams
do not install Kyverno inside their application charts. They submit workloads
that satisfy the policies owned by the platform.

## Why This Is GitOps

The desired state is committed in Git:

```text
k8s/gitops/dev/applications/kyverno-dev.yaml
k8s/addons/kyverno/values.yaml
```

Argo CD reads the pinned Helm chart and the CPEmon values file, then reconciles
the Kyverno controllers and CRDs into the `kyverno` namespace.

## Local Validation

Run the repository verifier:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-kyverno-installation.ps1
```

Render the chart locally:

```powershell
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update kyverno
helm template kyverno kyverno/kyverno `
  --version 3.8.1 `
  --namespace kyverno `
  --values k8s/addons/kyverno/values.yaml
```

The render check proves that the pinned chart and committed values can produce
Kubernetes manifests before Argo CD tries to sync them.

## Apply Through Argo CD

Apply the AppProject and Application after Argo CD is installed:

```powershell
kubectl apply -f k8s/addons/argocd/projects/cpemon-project.yaml
kubectl apply -f k8s/gitops/dev/applications/kyverno-dev.yaml
```

Inspect the Application:

```powershell
kubectl get application kyverno-dev -n argocd
kubectl describe application kyverno-dev -n argocd
argocd app get kyverno-dev
argocd app diff kyverno-dev
```

Sync manually:

```powershell
argocd app sync kyverno-dev
argocd app wait kyverno-dev --sync --health --timeout 300
```

## Runtime Validation

After sync, confirm the controllers and CRDs:

```powershell
kubectl get pods,svc,deploy -n kyverno
kubectl get crd | Select-String "kyverno.io|policies.kyverno.io|wgpolicyk8s.io"
kubectl get validatingwebhookconfiguration | Select-String "kyverno"
kubectl get mutatingwebhookconfiguration | Select-String "kyverno"
```

Expected outcome:

* admission controller is running
* background controller is running
* cleanup controller is running
* reports controller is running
* Kyverno CRDs exist before policies are applied

## Sync Order

Use this order for the governance lane:

1. `kyverno-dev`
2. Kyverno policy manifests from later subtasks
3. CPEmon workloads that must satisfy the policies

The controller must exist before `ClusterPolicy` resources are useful.

## Troubleshooting

Application rejected by AppProject:

```powershell
kubectl describe application kyverno-dev -n argocd
kubectl get appproject cpemon -n argocd -o yaml
```

Check that the project allows:

* source repo `https://kyverno.github.io/kyverno/`
* destination namespace `kyverno`
* cluster-scoped CRDs, ClusterRoles, ClusterRoleBindings, and webhooks

Chart render failure:

```powershell
helm template kyverno kyverno/kyverno `
  --version 3.8.1 `
  --namespace kyverno `
  --values k8s/addons/kyverno/values.yaml
```

CRD or webhook issues:

```powershell
kubectl get crd | Select-String "kyverno"
kubectl -n kyverno logs deploy/kyverno-admission-controller --tail=100
```

## Interview Framing

The short interview explanation:

```text
I installed Kyverno as a GitOps-managed platform add-on, not as an application
dependency. The Argo CD Application pins the chart version and uses values from
Git, while the AppProject limits the allowed chart repo and destination
namespace. That gives us a repeatable policy-as-code control plane before we
add individual policies.
```
