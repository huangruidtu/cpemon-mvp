# Kafka Namespace Runbook

## Purpose

Use this runbook to create and validate the Kafka namespace boundary.

Covered task:

- `CCPU-71`: Create Kafka namespace.

## Namespace Manifest

The Kafka namespace is declared in:

```text
k8s/base/namespaces.yaml
```

The namespace entry is:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kafka
  labels:
    app.kubernetes.io/part-of: cpemon-mvp
    app.kubernetes.io/name: kafka
    cpemon.io/layer: data-streaming
    cpemon.io/managed-by: gitops-ready-manifest
```

## Why Kafka Has Its Own Namespace

Kafka is a platform data-streaming dependency, not an application workload.

Keeping it in its own namespace gives the project a clean boundary for:

- Helm release ownership
- resource quotas and future limits
- storage and persistent volume troubleshooting
- NetworkPolicy rules
- ServiceMonitor and observability selection
- future Strimzi or MSK migration documentation
- RBAC separation between app operators and platform operators

The application namespace remains `cpemon`. Kafka platform resources live in `kafka`.

## Local Manifest Validation

Validate that the repository declares the namespace and required labels:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-namespace.ps1
```

Makefile shortcut:

```powershell
make kafka-namespace-check
```

This does not require a live cluster.

## Live Apply

Apply all platform namespaces:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
```

Makefile shortcut:

```powershell
make ns
```

## Live Validation

Check the Kafka namespace:

```powershell
kubectl get ns kafka
kubectl get ns kafka --show-labels
kubectl get ns kafka -o jsonpath="{.metadata.labels.cpemon\\.io/layer}{'\n'}"
```

Expected layer:

```text
data-streaming
```

The broader namespace check is:

```powershell
make ns-check
```

## Troubleshooting

If the namespace is missing:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
kubectl get ns kafka
```

If labels are missing or wrong:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
kubectl get ns kafka --show-labels
```

If apply fails:

```powershell
kubectl config current-context
kubectl cluster-info
kubectl auth can-i create namespace
kubectl auth can-i patch namespace kafka
```

## Interview Summary

I put Kafka in its own namespace because it is a platform data-streaming dependency rather than a CPEmon application workload. That gives a clearer operational boundary for Helm releases, storage, monitoring, NetworkPolicy, RBAC, and future migration to Strimzi or MSK. The namespace is committed in Git instead of being created by an undocumented one-off command.
