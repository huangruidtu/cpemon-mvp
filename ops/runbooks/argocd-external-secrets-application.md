# Argo CD External Secrets Application Runbook

This runbook validates the `external-secrets-dev` Argo CD Application.

## Purpose

`external-secrets-dev` installs External Secrets Operator as the controller
that reconciles AWS Secrets Manager values into Kubernetes Secrets.

```text
Application:    external-secrets-dev
Project:        cpemon
Chart repo:     https://charts.external-secrets.io
Chart:          external-secrets
Chart version:  2.6.0
Release name:   external-secrets
Values source:  https://github.com/huangruidtu/cpemon-mvp.git
Values file:    k8s/addons/external-secrets/values.yaml
Destination:    https://kubernetes.default.svc / external-secrets
```

The operator is platform/security infrastructure. It does not store secret
values in Git.

## GitOps Secret Boundary

Git owns:

* ESO controller installation values
* `SecretStore` or `ClusterSecretStore` manifests
* `ExternalSecret` manifests
* expected Kubernetes Secret names and keys
* workload `secretKeyRef` wiring

Git does not own:

* database passwords
* HMAC secrets
* AWS access keys
* decoded Kubernetes Secret values
* production `.env` files

Real secret material belongs in AWS Secrets Manager and is encrypted through
AWS KMS. ESO uses Kubernetes identity plus AWS IAM, preferably IRSA, to read
only approved remote secrets.

## Static Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-external-secrets-application.ps1
```

Render the same chart and values locally:

```powershell
helm repo add external-secrets https://charts.external-secrets.io
helm repo update external-secrets
helm template external-secrets external-secrets/external-secrets `
  --namespace external-secrets `
  --version 2.6.0 `
  --values k8s/addons/external-secrets/values.yaml
```

## Live Validation

Apply after Argo CD and the `cpemon` AppProject exist:

```powershell
kubectl apply -f k8s/addons/argocd/projects/cpemon-project.yaml
kubectl apply -f k8s/gitops/dev/applications/external-secrets-dev.yaml
```

Inspect the Application:

```powershell
kubectl get application external-secrets-dev -n argocd
kubectl describe application external-secrets-dev -n argocd
```

If the Argo CD CLI is installed:

```powershell
argocd app get external-secrets-dev
```

Inspect ESO:

```powershell
kubectl get pods,svc,deploy -n external-secrets
kubectl get crd | Select-String "external-secrets.io"
kubectl -n external-secrets logs deploy/external-secrets --tail=100
```

## IRSA Boundary

The Terraform contract creates an IAM role for:

```text
system:serviceaccount:external-secrets:external-secrets
```

Before live AWS sync, annotate the ESO service account with the Terraform
output:

```text
eks.amazonaws.com/role-arn: <external_secrets_irsa_role_arn>
```

This repository keeps `serviceAccount.annotations` empty in the committed
values file because the real role ARN is environment-specific.

## Sync Ordering

```text
external-secrets-dev
        |
        v
ESO CRDs and controller ready
        |
        v
CPEmon chart can render SecretStore and ExternalSecret
        |
        v
ESO reconciles Kubernetes Secrets from AWS Secrets Manager
        |
        v
CPEmon workloads consume Secret refs
```

Do not enable CPEmon `externalSecrets.enabled=true` in a live Argo CD sync until
the ESO controller and CRDs are ready and the AWS IAM/KMS contract is valid.

## Expected State

`Synced` means Argo CD applied the ESO chart resources.

`Healthy` requires the ESO controller, webhook, cert-controller, CRDs, and
webhook certificates to be ready.

## Interview Framing

GitOps does not mean putting secrets in Git. The strong answer is that Git
stores the desired contract and reconciliation objects, AWS Secrets Manager
stores the sensitive values, KMS protects encryption at rest, IRSA provides
scoped AWS access, and ESO creates the Kubernetes Secret projection consumed by
Pods.
