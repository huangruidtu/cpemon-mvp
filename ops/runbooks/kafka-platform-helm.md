# Kafka Platform Helm Runbook

## Purpose

Use this runbook to install and validate the Step 1 Kafka platform for CPEmon.

Covered task:

- `CCPU-70`: Install Kafka platform with Helm.

## Current Boundary

This runbook prepares the Helm workflow for Kafka. Live installation requires:

- Helm 3.8 or newer
- `kubectl`
- kubeconfig pointing to the target EKS cluster
- namespace `kafka`
- a default or explicit StorageClass
- node capacity for the Kafka pod and persistent volume

The current local shell used for this subtask does not have `helm` on PATH, so the repository records the workflow and validation boundary without claiming a live Helm install.

## Chart Choice

Step 1 uses the Bitnami Kafka Helm chart through OCI:

```text
oci://registry-1.docker.io/bitnamicharts/kafka
```

The Makefile pins the chart version through:

```text
KAFKA_CHART_VERSION ?= 32.4.3
```

Check the chart version before a real install:

```powershell
helm show chart oci://registry-1.docker.io/bitnamicharts/kafka --version 32.4.3
```

## Values File

Kafka values live at:

```text
k8s/addons/kafka/values.yaml
```

The Step 1 values are intentionally small:

- one KRaft controller
- no separate broker replicas
- internal `ClusterIP` service
- no external access
- plaintext internal listener for the first platform validation
- small resources preset
- persistent storage enabled with an 8 Gi volume
- metrics disabled until the observability subtask

This is not a production Kafka sizing model.

## Local Chart Inspection

Inspect chart defaults:

```powershell
helm show values oci://registry-1.docker.io/bitnamicharts/kafka --version 32.4.3
```

Inspect chart metadata:

```powershell
helm show chart oci://registry-1.docker.io/bitnamicharts/kafka --version 32.4.3
```

Makefile shortcut:

```powershell
make kafka-chart-show
```

## Render Before Install

Render the Kafka chart without applying it:

```powershell
helm template kafka oci://registry-1.docker.io/bitnamicharts/kafka `
  --namespace kafka `
  --version 32.4.3 `
  --values k8s/addons/kafka/values.yaml `
  > build/helm/kafka-rendered.yaml
```

Makefile shortcut:

```powershell
make kafka-template
```

This validates local chart rendering, not live broker readiness.

## Install or Upgrade

Install Kafka after the EKS cluster and `kafka` namespace exist:

```powershell
helm upgrade --install kafka oci://registry-1.docker.io/bitnamicharts/kafka `
  --namespace kafka `
  --version 32.4.3 `
  --values k8s/addons/kafka/values.yaml `
  --wait `
  --timeout 10m
```

Makefile shortcut:

```powershell
make kafka
```

## Validate Install

Check release and Kubernetes resources:

```powershell
helm status kafka -n kafka
kubectl get pods,svc,statefulset,pvc -n kafka
kubectl rollout status statefulset/kafka-controller -n kafka --timeout=10m
```

Makefile shortcut:

```powershell
make kafka-check
```

## Bootstrap Contract

For the Bitnami chart release name `kafka` in namespace `kafka`, the expected internal bootstrap service is:

```text
kafka.kafka.svc.cluster.local:9092
```

Application integration should consume this later through:

```text
KAFKA_BOOTSTRAP_SERVERS=kafka.kafka.svc.cluster.local:9092
```

Do not hardcode this directly in application code. It should enter workloads through Helm values or ConfigMap configuration in a later subtask.

## Troubleshooting

If Helm is not installed:

```powershell
winget install Helm.Helm
helm version --short
```

If the namespace is missing:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
kubectl get ns kafka
```

If Kafka pods are Pending:

```powershell
kubectl describe pod -n kafka -l app.kubernetes.io/instance=kafka
kubectl get storageclass
kubectl get pvc -n kafka
```

Common causes:

- no default StorageClass
- insufficient node CPU or memory
- persistent volume provisioning problem
- namespace not created

If the release fails:

```powershell
helm status kafka -n kafka
helm get values kafka -n kafka
helm get manifest kafka -n kafka
kubectl logs -n kafka -l app.kubernetes.io/instance=kafka --tail=120
```

## Rollback and Cleanup

Rollback to the previous release revision:

```powershell
helm history kafka -n kafka
helm rollback kafka <revision> -n kafka
```

Uninstall the release:

```powershell
helm uninstall kafka -n kafka
```

PersistentVolumeClaims may remain after uninstall. Review them before deleting data:

```powershell
kubectl get pvc -n kafka
```

## Interview Summary

For Step 1, I installed Kafka through Helm because the project was already using Helm as the Kubernetes packaging workflow. I kept the Kafka values small: one internal KRaft-based deployment, ClusterIP access, no external listener, and persistent storage enabled. That lets me validate the platform contract first: namespace, release, pods, service, and bootstrap address. Production concerns such as TLS, SASL, metrics, multi-broker sizing, Strimzi, or MSK are intentionally deferred so the first Kafka story stays explainable.
