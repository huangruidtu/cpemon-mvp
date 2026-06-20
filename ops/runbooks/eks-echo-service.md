# EKS Echo Service Runbook

## Purpose

Use this runbook to deploy and validate a small echo service in the `platform` namespace.

This runbook belongs to `CCPU-48`.

## Why Echo Exists

The echo service is a platform smoke test. It proves that basic Kubernetes workload primitives work before real CPEmon services move onto EKS.

It tests:

- Deployment scheduling
- Pod readiness
- ClusterIP Service routing
- label selector wiring
- local access through `kubectl port-forward`

It intentionally does not test external ALB access. That belongs to `CCPU-49`.

## Current Boundary

The EKS cluster has not been applied yet, so this runbook is prepared for the post-apply validation window.

## Files

```text
k8s/samples/echo/deploy.yaml
k8s/samples/echo/svc.yaml
```

## Deploy

```powershell
make echo
```

Direct commands:

```powershell
kubectl apply -f k8s/samples/echo/deploy.yaml
kubectl apply -f k8s/samples/echo/svc.yaml
```

## Validate

```powershell
make echo-check
```

Direct commands:

```powershell
kubectl get deploy,svc,pods -n platform -l app.kubernetes.io/name=echo
kubectl rollout status deployment/echo -n platform
kubectl describe pod -n platform -l app.kubernetes.io/name=echo
```

## Local Access

```powershell
make echo-port-forward
```

Then in another terminal:

```powershell
curl http://localhost:8080
```

Expected response:

```text
cpemon platform echo ok
```

## Troubleshooting

If the Deployment does not become ready:

```powershell
kubectl get pods -n platform -l app.kubernetes.io/name=echo
kubectl describe pod -n platform -l app.kubernetes.io/name=echo
kubectl logs -n platform -l app.kubernetes.io/name=echo
```

If the Service does not route:

```powershell
kubectl get svc echo -n platform
kubectl get endpoints echo -n platform
kubectl describe svc echo -n platform
```

The most common issue is label mismatch:

```text
Service selector must match Pod template labels.
```
