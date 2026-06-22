# Kyverno Labels and Non-Root Policies Runbook

This runbook validates the CPEmon label and non-root baseline policies.

## Policy Contracts

```text
Policy:       cpemon-require-standard-labels
Path:         k8s/policies/kyverno/baseline/require-standard-labels.yaml
Mode:         Enforce
```

```text
Policy:       cpemon-require-non-root-containers
Path:         k8s/policies/kyverno/baseline/require-non-root-containers.yaml
Mode:         Enforce
```

Both policies are deployed by:

```text
Application:  kyverno-policies-dev
```

## Why Labels Matter

Standard labels support day-two operations:

* Argo CD inventory
* Prometheus and Grafana grouping
* kubectl selectors
* ownership lookup
* cost and workload investigation

The baseline requires these labels on CPEmon Pods:

```text
app.kubernetes.io/name
app.kubernetes.io/instance
app.kubernetes.io/managed-by
app.kubernetes.io/part-of
app.kubernetes.io/component
```

## Why Non-Root Matters

Running containers as non-root reduces the blast radius if a process is
compromised. Disabling privilege escalation prevents a process from gaining
more privileges than expected.

The CPEmon Helm chart now renders:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

This is intentionally a baseline, not a full pod security program. Seccomp,
read-only root filesystems, image signing, and exception workflows can be added
after compatibility is tested.

## Local Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-labels-nonroot-policies.ps1
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

## Live Validation

After Kyverno policies are synced:

```powershell
kubectl get clusterpolicy cpemon-require-standard-labels
kubectl get clusterpolicy cpemon-require-non-root-containers
kubectl describe clusterpolicy cpemon-require-standard-labels
kubectl describe clusterpolicy cpemon-require-non-root-containers
```

Render CPEmon and confirm the desired fields before syncing:

```powershell
helm template cpemon deploy/helm/cpemon `
  --namespace cpemon `
  --values deploy/helm/cpemon/values-dev.yaml `
  | Select-String "app.kubernetes.io/part-of|runAsNonRoot|allowPrivilegeEscalation"
```

## Exception Strategy

Do not add broad exceptions by default.

If a workload truly cannot run as non-root:

* document the reason
* limit the exception to that workload
* prefer fixing the image or Dockerfile
* set an expiry or follow-up task

## Interview Framing

The concise answer:

```text
I added labels and non-root policies as baseline governance, then updated the
Helm chart so CPEmon satisfies those policies by default. Labels make operations
and cost investigation easier; non-root settings reduce container privilege
risk. I kept this scoped to a baseline instead of claiming full security
hardening.
```
