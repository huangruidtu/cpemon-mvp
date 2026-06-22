# Argo CD GitOps Deployment Validation Runbook

This runbook validates the CPEmon GitOps deployment path from Git.

## Purpose

The validation path answers:

```text
Can Argo CD find the Application, read the expected Git source, render the Helm
chart with the intended values, and expose sync/health status for operators?
```

## Repository Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-gitops-deployment-validation.ps1
```

This validates:

* `cpemon-dev` Application exists
* repo URL is explicit
* target revision is explicit
* chart path is `deploy/helm/cpemon`
* values file is `values-dev.yaml`
* destination namespace is `cpemon`
* sync policy is manual
* Helm can render the CPEmon chart with dev values

## Local Render Check

```powershell
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

This proves local chart rendering. It does not prove Argo CD can reach Git or
that the cluster can run the workloads.

## Live Argo CD Validation

After Argo CD is installed and kubeconfig points to the target cluster:

```powershell
kubectl apply -f k8s/addons/argocd/projects/cpemon-project.yaml
kubectl apply -f k8s/gitops/dev/applications/cpemon-dev.yaml
kubectl get application cpemon-dev -n argocd
kubectl describe application cpemon-dev -n argocd
```

With the Argo CD CLI:

```powershell
argocd app get cpemon-dev
argocd app diff cpemon-dev
argocd app sync cpemon-dev
argocd app wait cpemon-dev --health --sync --timeout 300
```

## Expected Output Shape

The Application should show:

```text
Name:               cpemon-dev
Project:            cpemon
Server:             https://kubernetes.default.svc
Namespace:          cpemon
Repo:               https://github.com/huangruidtu/cpemon-mvp.git
Target:             HEAD
Path:               deploy/helm/cpemon
Sync Policy:        Manual
Sync Status:        Synced or OutOfSync
Health Status:      Healthy, Progressing, Degraded, or Missing
```

## What This Proves

Repository validation proves the desired GitOps contract is reviewable and
renderable.

Live validation proves Argo CD can read the source, compare desired and live
state, and reconcile the target cluster.

## What This Does Not Prove

It does not prove:

* CI built and pushed a real image tag
* AWS Secrets Manager contains live secret values
* ESO/IRSA/KMS sync works
* Kafka is reachable
* NetworkPolicy enforcement works
* ALB/Ingress external access works

Those belong to their own validation runbooks.
