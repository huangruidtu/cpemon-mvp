# CPEmon Secret Management Runbook

## Purpose

Use this runbook to operate and troubleshoot the CPEmon secret-management path:

```text
AWS Secrets Manager
        |
        | encrypted at rest with AWS KMS
        v
External Secrets Operator on EKS
        |
        | authenticated through IRSA
        v
Kubernetes Secret
        |
        v
CPEmon workloads through secretKeyRef
```

This runbook belongs to `CCPU-158`.

## Required Tools

Local tools:

```powershell
helm version
terraform version
aws --version
kubectl version --client
```

This repository can validate Helm and Terraform syntax locally, but live secret sync requires `kubectl`, kubeconfig, an EKS cluster, External Secrets Operator CRDs, AWS Secrets Manager secrets, IAM, and KMS permissions.

## Secret Contract

The app-facing Kubernetes Secret contract is:

| Kubernetes Secret | Key | Consumer |
| --- | --- | --- |
| `cpemon-db` | `dsn` | `cpemon-api`, `acs-ingest`, `cpemon-writer` |
| `cpemon-acs-hmac` | `hmac-secret` | `acs-ingest` |
| `mysql-auth` | `mysql-root-password` | optional MySQL template |
| `mysql-auth` | `mysql-username` | optional MySQL template |
| `mysql-auth` | `mysql-password` | optional MySQL template |
| `mysql-auth` | `mysql-database` | optional MySQL template |

The AWS Secrets Manager dev path convention is:

```text
cpemon/dev/cpemon-db
cpemon/dev/cpemon-acs-hmac
cpemon/dev/mysql-auth
```

Store the values as JSON objects so ESO can map properties to Kubernetes Secret keys:

```json
{
  "dsn": "..."
}
```

```json
{
  "hmac-secret": "..."
}
```

```json
{
  "mysql-root-password": "...",
  "mysql-username": "...",
  "mysql-password": "...",
  "mysql-database": "..."
}
```

Do not commit these values.

## Preflight

Validate the chart render boundary first:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-cpemon-eso-render.ps1 `
  -Helm "C:\Users\Rui Huang\AppData\Local\Microsoft\WinGet\Packages\Helm.Helm_Microsoft.Winget.Source_8wekyb3d8bbwe\windows-amd64\helm.exe"
```

Expected:

```text
SecretStore count: 1
ClusterSecretStore count: 0
ExternalSecret count: 3
PASS: ESO render validation completed.
```

Validate Terraform syntax:

```powershell
terraform -chdir=infra/terraform/envs/dev fmt -check
terraform -chdir=infra/terraform/envs/dev validate
```

If the local backend cache has expired AWS SSO credentials, use a temporary `TF_DATA_DIR` for validation:

```powershell
$env:TF_DATA_DIR = Join-Path $env:TEMP "cpemon-tf-validate"
terraform -chdir=infra/terraform/envs/dev init -backend=false
terraform -chdir=infra/terraform/envs/dev validate
Remove-Item Env:\TF_DATA_DIR
```

## Install Assumptions

Before live secret sync, these must exist:

- EKS cluster and kubeconfig.
- IAM OIDC provider for the EKS cluster.
- ESO IAM role from `infra/terraform/modules/external_secrets_irsa`.
- External Secrets Operator installed.
- ESO service account annotated with the IAM role ARN.
- AWS Secrets Manager secrets under the agreed path convention.
- KMS key policy that allows decrypt when customer managed KMS keys are used.
- CPEmon Helm chart installed with `externalSecrets.enabled=true`.

## Terraform Outputs

After Terraform apply, capture:

```powershell
terraform -chdir=infra/terraform/envs/dev output external_secrets_irsa_role_arn
terraform -chdir=infra/terraform/envs/dev output external_secrets_service_account_subject
terraform -chdir=infra/terraform/envs/dev output eks_oidc_provider_arn
```

Expected subject:

```text
system:serviceaccount:external-secrets:external-secrets
```

## ESO Service Account Check

Check the service account annotation:

```powershell
kubectl -n external-secrets get sa external-secrets -o yaml
```

Expected annotation:

```yaml
eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/cpemon-dev-external-secrets-role
```

If it is missing, update the ESO Helm values or service account manifest. Do not add AWS access keys as a workaround.

## Apply CPEmon ESO Resources

Render locally:

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml --set externalSecrets.enabled=true
```

Install or upgrade when the cluster is ready:

```powershell
helm upgrade --install cpemon deploy/helm/cpemon `
  -n cpemon `
  --create-namespace `
  -f deploy/helm/cpemon/values-dev.yaml `
  --set externalSecrets.enabled=true
```

## Live Validation

Check store and external secrets:

```powershell
kubectl -n cpemon get secretstore cpemon-aws-secretsmanager
kubectl -n cpemon get externalsecret
kubectl -n cpemon describe externalsecret cpemon-db
kubectl -n cpemon describe externalsecret cpemon-acs-hmac
kubectl -n cpemon describe externalsecret mysql-auth
```

Check app-facing Secrets exist without decoding values:

```powershell
kubectl -n cpemon get secret cpemon-db
kubectl -n cpemon get secret cpemon-acs-hmac
kubectl -n cpemon get secret mysql-auth
```

Check required keys without printing values:

```powershell
kubectl -n cpemon get secret cpemon-db -o jsonpath="{.data.dsn}" | Measure-Object -Character
kubectl -n cpemon get secret cpemon-acs-hmac -o jsonpath="{.data.hmac-secret}" | Measure-Object -Character
```

Do not decode and paste values into chat, Jira, logs, or screenshots.

## Workload Validation

After Secrets exist, validate the workloads:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-cpemon-api-db.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-cpemon-writer-db.ps1
```

The API check proves startup DB connection and health endpoint.

The writer check proves DB connection plus worker-loop write-path signals.

## Failure Modes

### ExternalSecret Not Ready

Check:

```powershell
kubectl -n cpemon describe externalsecret cpemon-db
kubectl -n external-secrets logs deploy/external-secrets --tail=200
```

Likely causes:

- SecretStore region is wrong.
- Remote key does not exist in AWS Secrets Manager.
- Remote property does not exist in the JSON secret.
- ESO service account is missing the IRSA annotation.
- IAM policy does not allow the secret ARN.
- KMS key policy does not allow decrypt.

### AccessDenied From AWS

Check:

```powershell
kubectl -n external-secrets logs deploy/external-secrets --tail=200
```

Likely causes:

- IAM role trust policy subject does not match the service account.
- Secret ARN pattern is too narrow or wrong.
- Customer managed KMS key policy does not include the ESO role.
- AWS account or region mismatch.

### Secret Exists But Pod Still Fails

Check:

```powershell
kubectl -n cpemon get deploy cpemon-api -o yaml
kubectl -n cpemon logs deployment/cpemon-api --tail=200
kubectl -n cpemon logs deployment/cpemon-writer --tail=200
```

Likely causes:

- Secret key name does not match workload `secretKeyRef`.
- DSN points to the wrong host or database.
- MySQL is not reachable.
- Database schema is missing.
- Pod has not restarted after a secret update.

## Rotation Notes

Secret rotation has two layers:

- source rotation in AWS Secrets Manager
- workload pickup in Kubernetes

ESO can update the Kubernetes Secret after the refresh interval. The workload may still need a rollout restart if the secret is consumed as an environment variable:

```powershell
kubectl -n cpemon rollout restart deployment/cpemon-api
kubectl -n cpemon rollout restart deployment/acs-ingest
kubectl -n cpemon rollout restart deployment/cpemon-writer
```

For database credential rotation, plan for application connection pools, user grants, and rollback before rotating production credentials.

## Recovery Checklist

If secret sync breaks:

1. Confirm the AWS secret exists in the expected region and path.
2. Confirm the JSON property name matches the ExternalSecret.
3. Confirm ESO service account annotation points to the expected IAM role.
4. Confirm IAM policy allows the secret ARN.
5. Confirm KMS policy allows decrypt when using a customer managed key.
6. Confirm `kubectl describe externalsecret` shows Ready.
7. Confirm the Kubernetes Secret exists and contains the expected keys.
8. Restart workloads only after the Secret is present and correct.

## Interview Summary

The key answer is that secret management is not one object. Git defines the desired contract, AWS Secrets Manager stores the sensitive values, KMS protects the encrypted material, IRSA gives ESO scoped AWS access, ESO reconciles the Kubernetes Secret, and the workload consumes it through `secretKeyRef`. Local render validation proves the contract; live EKS/AWS validation proves the runtime.
