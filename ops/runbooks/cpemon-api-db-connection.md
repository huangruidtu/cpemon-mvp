# CPEmon API DB Connection Verification

## Purpose

Use this runbook to verify that `cpemon-api` is wired to the database Secret correctly and can start with a working MySQL connection.

This runbook belongs to `CCPU-66`.

## What This Check Proves

When run against a live cluster, the check proves:

- Kubernetes Secret `cpemon-db` exists in namespace `cpemon`.
- Secret key `dsn` exists without printing the Secret value.
- `deployment/cpemon-api` sources `DB_DSN` from `cpemon-db/dsn`.
- The Deployment rollout completes.
- Recent logs do not show `failed to initialize database`.
- `/healthz` responds through a temporary port-forward.

The check does not print database credentials.

## Prerequisites

Required tools:

```powershell
kubectl version --client
```

Required cluster state:

```powershell
kubectl get ns cpemon
kubectl -n cpemon get secret cpemon-db
kubectl -n cpemon get deploy cpemon-api
kubectl -n cpemon get svc mysql
```

The `cpemon-db` Secret must contain key `dsn`.

## Run

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-cpemon-api-db.ps1
```

Optional overrides:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-cpemon-api-db.ps1 `
  -Namespace cpemon `
  -Deployment cpemon-api `
  -SecretName cpemon-db `
  -SecretKey dsn
```

## Expected Output

Expected signals:

```text
OK: Secret cpemon/cpemon-db contains key 'dsn'. Secret value was not printed.
OK: DB_DSN points to cpemon-db/dsn.
deployment "cpemon-api" successfully rolled out
OK: /healthz returned HTTP 200.
PASS: cpemon-api DB connection verification completed for namespace cpemon.
```

The logs may include:

```text
database connection established
```

If the pod started before the log tail window, the script may warn that the success marker was not found. In that case, inspect older logs or restart the Deployment only when it is safe.

## Failure Modes

### Secret Missing

Symptom:

```text
secrets "cpemon-db" not found
```

Check:

```powershell
kubectl -n cpemon get secret cpemon-db
kubectl -n cpemon get externalsecret
```

Likely causes:

- Secret was not manually bootstrapped.
- External Secrets Operator has not synced yet.
- Wrong namespace.

### Secret Key Missing

Symptom:

```text
Secret cpemon/cpemon-db exists, but key 'dsn' is missing.
```

Check:

```powershell
kubectl -n cpemon get secret cpemon-db -o jsonpath='{.data}'
```

Do not decode or paste the value into logs or tickets unless there is a controlled secret-handling process.

### Deployment Uses Wrong Secret

Symptom:

```text
DB_DSN does not point to cpemon-db/dsn.
```

Check:

```powershell
kubectl -n cpemon get deploy cpemon-api -o yaml
```

The expected env block is:

```yaml
- name: DB_DSN
  valueFrom:
    secretKeyRef:
      name: cpemon-db
      key: dsn
```

### Database Initialization Fails

Symptom:

```text
failed to initialize database
```

Check:

```powershell
kubectl -n cpemon logs deployment/cpemon-api --tail=200
kubectl -n cpemon get pods -l app=mysql
kubectl -n cpemon get svc mysql
kubectl -n cpemon get endpoints mysql
```

Likely causes:

- MySQL pod is not running.
- MySQL Service has no endpoints.
- `DB_DSN` points to the wrong host, database, username, or password.
- NetworkPolicy blocks egress from `cpemon-api` to MySQL.

## Validation Boundary

In this Codex run, local validation can prove the script parses, docs exist, Go tests pass, and Helm still renders.

It cannot prove live DB connectivity until:

- `kubectl` is installed and available.
- kubeconfig points to the target cluster.
- the `cpemon` namespace and workloads exist.
- required Secrets exist.
- MySQL is running.
