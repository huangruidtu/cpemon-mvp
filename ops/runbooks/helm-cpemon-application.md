# CPEmon Helm Application Runbook

## Purpose

Use this runbook to validate, render, and later install the CPEmon application Helm chart.

The chart lives at:

```text
deploy/helm/cpemon
```

It packages the application layer above the AWS/EKS infrastructure and Kubernetes platform add-ons:

```text
Terraform AWS/EKS foundation
  -> Kubernetes platform add-ons
  -> CPEmon Helm chart
  -> future Argo CD/GitOps deployment
```

## Current Boundary

The chart is ready for local validation and render review.

Live install is deferred until:

- the EKS cluster exists
- kubeconfig points to the target cluster
- the `cpemon` namespace exists
- ECR image pull access exists
- required runtime Secrets exist
- optional platform CRDs/controllers exist before enabling their templates

This runbook therefore separates:

```text
pre-apply validation -> future live install -> future post-install checks
```

## Required Tools

Local validation needs:

- `helm`
- `make`

Check:

```powershell
helm version --short
make --version
```

If a newly installed Helm binary is not visible in the current shell, pass it explicitly:

```powershell
make helm-cpemon-validate HELM="C:/path/to/helm.exe"
```

## Chart Inputs

Default chart values:

```text
deploy/helm/cpemon/values.yaml
```

Dev override values:

```text
deploy/helm/cpemon/values-dev.yaml
```

The dev file should stay small. It should only override environment-specific values such as namespace, image tag, dev Secret references, replicas, and optional feature flags.

## Required Pre-Existing Secrets

The chart references Secrets by name and key. It does not create real secret material.

Required before live install:

| Purpose | Secret | Key |
| --- | --- | --- |
| Pull private ECR images | `cpemon-ecr-regcred` | Docker config secret data |
| Database DSN | `cpemon-db` | `dsn` |
| ACS webhook HMAC | `cpemon-acs-hmac` | `hmac-secret` |

Check later in a live cluster:

```powershell
kubectl get secret -n cpemon cpemon-ecr-regcred
kubectl get secret -n cpemon cpemon-db
kubectl get secret -n cpemon cpemon-acs-hmac
```

## Validate Locally

Preferred validation:

```powershell
make helm-cpemon-validate
```

If Helm is installed but not on `PATH`:

```powershell
make helm-cpemon-validate HELM="C:/path/to/helm.exe"
```

This runs:

```text
helm lint
helm template
```

The rendered output is written to:

```text
build/helm/cpemon-rendered.yaml
```

`build/` is ignored by Git because rendered output is local validation evidence, not source.

## Render Without Make

The equivalent direct Helm commands are:

```powershell
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

These commands do not contact the cluster and do not create resources.

## Review Rendered Output

After rendering, inspect:

```powershell
Select-String -Path build/helm/cpemon-rendered.yaml -Pattern "kind:|name:|image:|configMapKeyRef|secretKeyRef"
```

Review checklist:

- three application Deployments render when workloads are enabled
- three Services render for HTTP and metrics
- images use the expected registry, repository, and tag
- Deployment selectors match pod labels
- Services select the same stable labels as the pods
- non-secret config uses `configMapKeyRef`
- sensitive runtime values use `secretKeyRef`
- optional resources do not render unless enabled

## Render Optional Platform Features

Optional features are disabled by default.

Render all optional features for review:

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml `
  --set ingress.enabled=true `
  --set serviceMonitor.enabled=true `
  --set pdb.enabled=true `
  --set networkPolicy.enabled=true
```

Expected optional resources:

- 1 Ingress
- 1 ServiceMonitor
- 2 PodDisruptionBudgets
- 3 NetworkPolicies

Do not enable optional features in a live cluster until the platform dependency exists:

| Feature | Dependency |
| --- | --- |
| Ingress | ingress controller |
| ServiceMonitor | Prometheus Operator CRDs |
| PDB | enough replicas for meaningful disruption budgets |
| NetworkPolicy | policy enforcement from the CNI or policy engine |

## Future Live Install

Use this only after the cluster and required dependencies exist:

```powershell
helm upgrade --install cpemon deploy/helm/cpemon `
  -n cpemon `
  -f deploy/helm/cpemon/values-dev.yaml `
  --set global.imageTag=<image-tag>
```

If the namespace does not exist yet:

```powershell
kubectl create namespace cpemon
```

For production-like use, avoid deploying placeholder tags such as `__IMAGE_TAG__`. Prefer an immutable tag from CI, such as a Git SHA or release version.

## Future Post-Install Checks

After live install:

```powershell
helm status cpemon -n cpemon
helm get values cpemon -n cpemon
helm get manifest cpemon -n cpemon
```

Kubernetes checks:

```powershell
kubectl get deploy,svc,configmap -n cpemon
kubectl get pods -n cpemon -l app.kubernetes.io/part-of=cpemon-mvp
kubectl rollout status deployment/cpemon-api -n cpemon
kubectl rollout status deployment/acs-ingest -n cpemon
kubectl rollout status deployment/cpemon-writer -n cpemon
```

Application checks depend on the access path:

```powershell
kubectl port-forward -n cpemon svc/cpemon-api 18080:8080
curl http://127.0.0.1:18080/healthz
```

If Ingress is enabled:

```powershell
kubectl get ingress -n cpemon
kubectl describe ingress -n cpemon
```

If ServiceMonitor is enabled:

```powershell
kubectl get servicemonitor -n monitoring cpemon-services
```

If NetworkPolicy is enabled:

```powershell
kubectl get networkpolicy -n cpemon
kubectl describe networkpolicy -n cpemon
```

## Upgrade Workflow

For chart or values changes:

```powershell
make helm-cpemon-validate
helm upgrade --install cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml --set global.imageTag=<image-tag>
```

Recommended review order:

1. Review `values.yaml` and environment override file.
2. Run lint/template locally.
3. Review rendered selectors, services, config, and secret references.
4. Install or upgrade in the target cluster.
5. Check rollout and logs.

## Rollback Workflow

List release history:

```powershell
helm history cpemon -n cpemon
```

Rollback:

```powershell
helm rollback cpemon <revision> -n cpemon
```

Then check:

```powershell
helm status cpemon -n cpemon
kubectl rollout status deployment/cpemon-api -n cpemon
kubectl rollout status deployment/acs-ingest -n cpemon
kubectl rollout status deployment/cpemon-writer -n cpemon
```

## Troubleshooting

If `make helm-cpemon-validate` fails because Helm is missing:

- confirm `helm version --short`
- open a new shell after installation
- pass `HELM=C:/path/to/helm.exe`

If `helm lint` fails:

- inspect the template and values mentioned in the error
- validate YAML indentation
- check `values.schema.json` for type expectations
- confirm required values exist

If `helm template` fails:

- look for nil or missing values
- check helper names in `_helpers.tpl`
- check `range` and `with` blocks for indentation
- render with a smaller values override to isolate the problem

If a future live install fails:

- confirm the namespace exists
- confirm required Secrets exist
- confirm image tags exist in ECR
- confirm optional CRDs exist before enabling optional templates
- check `helm status`
- check pod events with `kubectl describe pod`

## Migration Decision Summary

The CPEmon MVP started with raw Kubernetes YAML because that is clear and useful for early learning.

The migration to Helm is introduced when the application needs:

- repeatable rendering
- environment-specific values
- safer secret references
- reusable workload structure
- optional platform integrations
- a clean handoff to future Argo CD/GitOps

Helm is application packaging. Terraform still owns AWS infrastructure. Kubernetes add-ons still provide platform capabilities. Argo CD can later consume this chart and keep the cluster synced from Git.

## Interview Summary

A concise interview explanation:

> I moved the CPEmon application from raw Kubernetes manifests into a Helm chart because the deployment needed to become repeatable across environments. The chart separates reusable Kubernetes object structure from environment-specific values, references Secrets without committing secret material, and supports optional integrations like Ingress, ServiceMonitor, PDB, and NetworkPolicy. I added Makefile validation so the chart can be linted and rendered before any live install. This prepares the application for a future GitOps workflow with Argo CD.
