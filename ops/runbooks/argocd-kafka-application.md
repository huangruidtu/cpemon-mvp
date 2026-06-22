# Argo CD Kafka Application Runbook

This runbook validates the `kafka-dev` Argo CD Application.

## Purpose

`kafka-dev` brings the existing Kafka Helm workflow into the GitOps model.

```text
Application:    kafka-dev
Project:        cpemon
Chart repo:     registry-1.docker.io/bitnamicharts
Chart:          kafka
Chart version:  32.4.3
Values source:  https://github.com/huangruidtu/cpemon-mvp.git
Values file:    k8s/addons/kafka/values.yaml
Destination:    https://kubernetes.default.svc / kafka
```

This keeps the platform story consistent: Story 8 introduced Kafka through a
Helm chart and a small values file; Story 11 lets Argo CD reconcile the same
boundary from Git.

## Argo CD Helm Boundary

Argo CD uses Helm to render manifests. Argo CD owns the application lifecycle
after rendering.

The Application uses `sources` because the chart comes from the Bitnami OCI
Helm repository while the values file lives in this Git repository.

Official Argo CD references:

* Helm charts can be installed declaratively by `Application` manifests:
  https://argo-cd.readthedocs.io/en/latest/user-guide/helm/
* Value files can be sourced from a separate repository with multiple sources:
  https://argo-cd.readthedocs.io/en/latest/user-guide/helm/#values-files

## Static Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-kafka-application.ps1
```

Render the same chart and values locally:

```powershell
helm template kafka oci://registry-1.docker.io/bitnamicharts/kafka `
  --namespace kafka `
  --version 32.4.3 `
  --values k8s/addons/kafka/values.yaml
```

## Live Validation

Apply after Argo CD and the `cpemon` AppProject exist:

```powershell
kubectl apply -f k8s/addons/argocd/projects/cpemon-project.yaml
kubectl apply -f k8s/gitops/dev/applications/kafka-dev.yaml
```

Inspect the Application:

```powershell
kubectl get application kafka-dev -n argocd
kubectl describe application kafka-dev -n argocd
```

If the Argo CD CLI is installed:

```powershell
argocd app get kafka-dev
```

Inspect Kafka resources:

```powershell
kubectl get pods,svc,statefulset,pvc -n kafka
kubectl rollout status statefulset/kafka-controller -n kafka --timeout=10m
```

## Expected State

Kafka should become `Synced` after Argo CD renders the pinned Bitnami chart
with `k8s/addons/kafka/values.yaml`.

Kafka should become `Healthy` only after:

* the `kafka` namespace exists
* the cluster has enough node capacity
* persistent volume provisioning succeeds
* the `kafka-controller` StatefulSet is ready
* the bootstrap service exists

## Sequencing

Kafka is a platform dependency for CPEmon workload event publishing and
consuming. In a manual rollout, sync `kafka-dev` before expecting CPEmon Kafka
producer or consumer paths to become healthy.

The CPEmon application can still render while Kafka is unavailable, but event
paths that need `KAFKA_BOOTSTRAP_SERVERS` will not be operational until Kafka
is ready.
