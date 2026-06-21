# CPEmon ESO Render Validation

## Purpose

Use this runbook to validate the External Secrets Operator render boundary before a live EKS/AWS environment is available.

This runbook belongs to `CCPU-157`.

## What Local Render Validation Proves

Local render validation proves:

- Helm values and templates are syntactically valid.
- ESO resources are disabled by default.
- Enabling ESO renders one `SecretStore` or `ClusterSecretStore`.
- Enabling ESO renders three `ExternalSecret` resources.
- Rendered resources contain remote secret references and properties.
- Rendered resources do not contain obvious secret values or Kubernetes Secret payloads.

It does not prove:

- ESO CRDs are installed in a live cluster.
- IRSA trust policy works.
- AWS Secrets Manager can be reached.
- KMS decrypt works.
- ExternalSecret reconciliation succeeds.
- Pods can start with the synced Kubernetes Secrets.
- DB reads or writes work.

## Run

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-cpemon-eso-render.ps1
```

If Helm is installed but not on `PATH`, pass it explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-cpemon-eso-render.ps1 `
  -Helm "C:\Users\Rui Huang\AppData\Local\Microsoft\WinGet\Packages\Helm.Helm_Microsoft.Winget.Source_8wekyb3d8bbwe\windows-amd64\helm.exe"
```

Or through Make:

```powershell
make cpemon-eso-render-check
```

## Expected Output

Expected counts:

```text
SecretStore count: 1
ClusterSecretStore count: 0
ExternalSecret count: 3
PASS: ESO render validation completed.
```

Expected remote references:

```text
cpemon/dev/cpemon-db -> dsn
cpemon/dev/cpemon-acs-hmac -> hmac-secret
cpemon/dev/mysql-auth -> mysql-root-password, mysql-username, mysql-password, mysql-database
```

## Why This Matters

This check catches the mistakes that local rendering can catch:

- ESO resources accidentally enabled by default
- broken Helm templates
- missing ExternalSecret resources
- wrong remote key or property names
- accidental rendering of Kubernetes Secret payloads

It deliberately does not pretend to validate cloud runtime behavior.

## Live Validation Later

After the EKS and AWS dependencies exist, validate live reconciliation with:

```powershell
kubectl -n cpemon get secretstore cpemon-aws-secretsmanager
kubectl -n cpemon get externalsecret
kubectl -n cpemon describe externalsecret cpemon-db
kubectl -n cpemon get secret cpemon-db
```

Do not decode or paste secret values into tickets or chat.
