# CPEmon Writer DB Write-Path Verification

## Purpose

Use this runbook to verify that `cpemon-writer` is wired to the database safely and can run the worker loop without DB write-path errors.

This runbook belongs to `CCPU-67`.

## What This Check Proves

When run against a live cluster, the check proves:

- Kubernetes Secret `cpemon-db` exists in namespace `cpemon`.
- Secret key `dsn` exists without printing the Secret value.
- ConfigMap `cpemon-app-config` contains `HTTP_ADDR`, `WORKER_INTERVAL`, and `BATCH_SIZE`.
- `deployment/cpemon-writer` sources `DB_DSN` from `cpemon-db/dsn`.
- `deployment/cpemon-writer` sources worker settings from `cpemon-app-config`.
- The Deployment rollout completes.
- Recent logs do not show `failed to initialize database`.
- Recent logs do not show `cpemon-writer runOnce error`.
- `/healthz` responds through a temporary port-forward.

The check does not print database credentials.

## Why Writer Needs Its Own Check

`cpemon-api` proves the application can open a database connection. `cpemon-writer` proves a different operational path:

```text
DB_DSN -> appdb.Init -> worker loop -> runOnce -> SELECT ingest_events -> UPDATE ingest_events
```

That makes this check more than a startup check. The key writer-specific failure signal is `cpemon-writer runOnce error`, because it usually means the worker could not query or update the `ingest_events` table.

## Prerequisites

Required tools:

```powershell
kubectl version --client
```

Required cluster state:

```powershell
kubectl get ns cpemon
kubectl -n cpemon get secret cpemon-db
kubectl -n cpemon get configmap cpemon-app-config
kubectl -n cpemon get deploy cpemon-writer
kubectl -n cpemon get svc mysql
```

The `cpemon-db` Secret must contain key `dsn`.

The `cpemon-app-config` ConfigMap must contain:

```text
HTTP_ADDR
WORKER_INTERVAL
BATCH_SIZE
```

## Run

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-cpemon-writer-db.ps1
```

Or through Make:

```powershell
make cpemon-writer-db-check
```

Optional overrides:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-cpemon-writer-db.ps1 `
  -Namespace cpemon `
  -Deployment cpemon-writer `
  -SecretName cpemon-db `
  -SecretKey dsn `
  -ConfigMapName cpemon-app-config
```

## Expected Output

Expected signals:

```text
OK: Secret cpemon/cpemon-db contains key 'dsn'. Secret value was not printed.
OK: ConfigMap cpemon/cpemon-app-config contains WORKER_INTERVAL, BATCH_SIZE, and HTTP_ADDR.
OK: DB_DSN points to cpemon-db/dsn.
OK: WORKER_INTERVAL points to cpemon-app-config/WORKER_INTERVAL.
OK: BATCH_SIZE points to cpemon-app-config/BATCH_SIZE.
deployment "cpemon-writer" successfully rolled out
OK: /healthz returned HTTP 200.
PASS: cpemon-writer DB write-path verification completed for namespace cpemon.
```

Useful log markers:

```text
database connection established
cpemon-writer worker loop started
processing ingest_event
```

`processing ingest_event` appears only when there are queued rows ready to process. It is helpful but not required for an empty queue.

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

### ConfigMap Missing or Incomplete

Symptom:

```text
configmaps "cpemon-app-config" not found
```

or:

```text
ConfigMap cpemon/cpemon-app-config exists, but key 'BATCH_SIZE' is missing.
```

Check:

```powershell
kubectl -n cpemon get configmap cpemon-app-config -o yaml
```

Likely causes:

- Raw config manifest was not applied.
- Helm chart rendered with a different release or namespace.
- A key was renamed without updating the Deployment.

### Deployment Uses Wrong Secret or ConfigMap

Symptom:

```text
DB_DSN does not point to cpemon-db/dsn.
```

Check:

```powershell
kubectl -n cpemon get deploy cpemon-writer -o yaml
```

The expected env blocks are:

```yaml
- name: DB_DSN
  valueFrom:
    secretKeyRef:
      name: cpemon-db
      key: dsn
- name: WORKER_INTERVAL
  valueFrom:
    configMapKeyRef:
      name: cpemon-app-config
      key: WORKER_INTERVAL
- name: BATCH_SIZE
  valueFrom:
    configMapKeyRef:
      name: cpemon-app-config
      key: BATCH_SIZE
```

### Database Initialization Fails

Symptom:

```text
failed to initialize database
```

Check:

```powershell
kubectl -n cpemon logs deployment/cpemon-writer --tail=200
kubectl -n cpemon get pods -l app=mysql
kubectl -n cpemon get svc mysql
kubectl -n cpemon get endpoints mysql
```

Likely causes:

- MySQL pod is not running.
- MySQL Service has no endpoints.
- `DB_DSN` points to the wrong host, database, username, or password.
- NetworkPolicy blocks egress from `cpemon-writer` to MySQL.

### Worker Loop DB Error

Symptom:

```text
cpemon-writer runOnce error
```

Check:

```powershell
kubectl -n cpemon logs deployment/cpemon-writer --tail=300
```

Likely causes:

- `ingest_events` table does not exist.
- MySQL user can connect but lacks SELECT or UPDATE permissions.
- Schema version does not match the writer code.
- Database connection drops after startup.

## Optional End-to-End Queue Proof

If it is safe to insert a test row, create one queued `ingest_events` record through a controlled DB client and then watch for:

```text
processing ingest_event
```

After processing, the row should move to:

```text
status='done'
```

Do not run this against production data without an approved test-data process.

## Validation Boundary

In this Codex run, local validation can prove the script parses, docs exist, Go tests pass, and Helm still renders.

It cannot prove the live write path until:

- `kubectl` is installed and available.
- kubeconfig points to the target cluster.
- the `cpemon` namespace and workloads exist.
- required Secrets and ConfigMaps exist.
- MySQL is running with the expected schema.
