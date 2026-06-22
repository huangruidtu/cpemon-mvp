# Argo CD Installation Runbook

This runbook covers `CCPU-96: Install Argo CD`.

## Purpose

Argo CD is the GitOps deployment controller for CPEmon. It reconciles live
cluster state from Git so deployments are repeatable, reviewable, and easier to
debug than manual `kubectl apply` sessions.

This subtask does not yet create CPEmon Applications. It establishes the Argo
CD control plane and the minimum access path for later GitOps subtasks.

Follow-on project boundary:

```text
ops/runbooks/argocd-project.md
```

## Installation Boundary

For the learning environment, use the upstream Argo CD stable manifest:

```powershell
kubectl apply -f k8s/addons/argocd/namespace.yaml
kubectl apply -n argocd --server-side --force-conflicts `
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Why this approach:

* It matches the official getting-started workflow.
* It is fast enough for the learning environment.
* It avoids introducing another Helm chart before the project has an Argo CD
  application model.
* It keeps Step 1 focused on the GitOps control plane.

Production note:

Use a pinned Argo CD version, reviewed manifests, SSO/RBAC, TLS, backup
planning, and upgrade runbooks before treating this as production-ready.

## Verify Namespace

```powershell
kubectl get ns argocd
kubectl get ns argocd -o jsonpath="{.metadata.labels.cpemon\.io/layer}"
```

Expected layer label:

```text
delivery
```

## Verify Control Plane

```powershell
kubectl get pods -n argocd
kubectl get deploy -n argocd
kubectl get svc -n argocd
```

Expected components:

* `argocd-server`
* `argocd-repo-server`
* `argocd-application-controller`
* `argocd-applicationset-controller`
* `argocd-redis`
* `argocd-dex-server`

Wait for the pods:

```powershell
kubectl -n argocd wait --for=condition=Ready pod `
  -l app.kubernetes.io/part-of=argocd `
  --timeout=300s
```

## Access The UI

Port-forward:

```powershell
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open:

```text
https://localhost:8080
```

Initial admin password:

```powershell
kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}" | base64 -d
```

On Windows PowerShell, if `base64 -d` is unavailable:

```powershell
$encoded = kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}"
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
```

## CLI Boundary

The `argocd` CLI is useful for login and app operations:

```powershell
argocd version --client
argocd login localhost:8080
argocd app list
```

It is not required for this repository check. If a later task requires CLI
login and `argocd` is missing from `PATH`, stop and install it before
continuing.

## Common Failures

Namespace exists but pods are missing:
Re-run the install manifest apply and check for Kubernetes API errors.

Pods are pending:
Check node capacity, image pull errors, and events.

Server is running but UI is not reachable:
Confirm the port-forward is still active and that the local browser uses
`https://localhost:8080`.

Admin secret is missing:
Wait for `argocd-server` to finish startup, then query the secret again.

## Interview Explanation

I introduced Argo CD after Terraform and Helm because Terraform owns cloud
infrastructure, Helm packages Kubernetes workloads, and Argo CD reconciles the
cluster from Git. That ordering keeps responsibilities clear: CI builds images,
Git records desired state, and Argo CD performs continuous delivery.
