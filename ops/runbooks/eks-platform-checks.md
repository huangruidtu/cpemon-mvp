# EKS Platform Checks Runbook

## Purpose

Use this runbook after the EKS cluster exists to run repeatable platform checks for `CCPU-5`.

The checks cover:

- Kubernetes access
- namespace boundaries
- metrics-server
- AWS Load Balancer Controller
- default StorageClass
- echo workload
- ALB Ingress external access
- baseline NetworkPolicy inspection

## Current Boundary

The EKS cluster has not been applied yet in the current project phase.

That means these commands are prepared now, but live execution belongs to the post-apply phase.

If the cluster does not exist or `kubectl` is not installed, the Makefile targets should fail early and clearly.

## Check Layers

Think of the checks in layers:

```text
Tooling and access
  -> Kubernetes namespaces
  -> platform add-ons
  -> storage
  -> internal smoke workload
  -> external ALB path
  -> network policy posture
```

This order matters because later checks depend on earlier ones.

For example, an ALB Ingress check is not meaningful if:

- kubeconfig cannot reach the cluster
- AWS Load Balancer Controller is not running
- the echo Service has no endpoints

## Preflight

```powershell
make platform-preflight
```

This checks:

```powershell
kubectl version --client=true
helm version
aws --version
kubectl config current-context
kubectl cluster-info
```

Interpretation:

- If `kubectl` is missing, install it before debugging Kubernetes YAML.
- If `kubectl config current-context` fails, kubeconfig is not ready.
- If `kubectl cluster-info` fails, the current context cannot reach the cluster.
- If `helm` is missing, add-on install targets cannot run.
- If `aws` is missing or unauthenticated, AWS-backed controllers and EKS access may fail later.

## Manifest Dry-Run

```powershell
make platform-manifest-plan
```

This runs client-side dry-run checks for the committed manifests:

- namespaces
- gp3 StorageClass candidate
- echo Deployment
- echo Service
- echo ALB Ingress
- NetworkPolicy baseline candidate

This is the Kubernetes equivalent of a lightweight plan step. It does not create resources, but it catches common schema and YAML problems before live apply.

## Full Platform Checks

```powershell
make platform-checks
```

This runs the post-apply platform inspection path:

```text
platform-preflight
ns-check
metrics-server-check
aws-lbc-check
storage-check
echo-check
echo-ingress-check
netpol-check
```

Use this after:

- Terraform EKS apply is complete.
- kubeconfig has been generated.
- metrics-server has been installed.
- AWS Load Balancer Controller has been installed.
- the echo service and Ingress have been applied.
- NetworkPolicy enforcement mode is understood.

## Single-Purpose Checks

Namespace check:

```powershell
make ns-check
```

Metrics check:

```powershell
make metrics-server-check
```

AWS Load Balancer Controller check:

```powershell
make aws-lbc-check
```

Storage check:

```powershell
make storage-check
```

Echo workload check:

```powershell
make echo-check
```

External access check:

```powershell
make echo-ingress-check
```

NetworkPolicy check:

```powershell
make netpol-check
```

## Troubleshooting Order

If `make platform-checks` fails, do not jump directly to the last error.

Debug in dependency order:

1. `make platform-preflight`
2. `make ns-check`
3. `make metrics-server-check`
4. `make aws-lbc-check`
5. `make storage-check`
6. `make echo-check`
7. `make echo-ingress-check`
8. `make netpol-check`

This keeps the investigation clean.

Example:

```text
If echo-ingress-check fails, first confirm aws-lbc-check and echo-check.
```

The Ingress cannot become healthy if the controller is not reconciling it or the Service has no endpoints.

## Interview Summary

Platform Makefile checks turn manual operational knowledge into repeatable commands. They give the team a shared way to answer: can we reach the cluster, are add-ons running, is storage configured, does a smoke workload run, can external traffic reach it, and what is the current policy posture? In a migration project, this matters because it separates platform readiness from application migration bugs.
