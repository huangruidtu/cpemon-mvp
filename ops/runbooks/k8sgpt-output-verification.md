# K8sGPT Output Verification

## Purpose

Prevent AI-assisted diagnostics from becoming blind trust.

## Verification Pattern

For every K8sGPT finding, capture:

```text
finding
Kubernetes evidence
GitOps evidence
metric evidence if relevant
operator decision
```

## Example

K8sGPT says:

```text
The pod cannot start because the referenced Secret does not exist.
```

Verify:

```powershell
kubectl describe pod -n cpemon <pod>
kubectl get secret -n cpemon missing-cpemon-database-secret
kubectl get deploy -n cpemon k8sgpt-demo-missing-secret -o yaml
```

## Trust Boundary

K8sGPT may summarize symptoms well, but only Kubernetes status, events, logs,
and metrics can confirm the operational truth.
