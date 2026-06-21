# Helm CPEmon Application

## Why This Story Exists

`CCPU-6` moves CPEmon from raw Kubernetes YAML toward a reusable Helm chart.

The previous stories prepared the layers below the application:

```text
CCPU-4: AWS and EKS infrastructure with Terraform
CCPU-5: Kubernetes platform add-ons
CCPU-6: CPEmon application packaging with Helm
```

This matters because a migration project is not only about starting a cluster. The application must also become repeatable, configurable, reviewable, and eventually GitOps-friendly.

## What Helm Is

Helm is a package manager and templating system for Kubernetes.

Instead of copying many environment-specific YAML files, a team defines:

- templates: reusable Kubernetes object patterns
- values: environment-specific inputs
- chart metadata: package identity and version
- release state: what Helm installed into a namespace

The mental model is:

```text
templates + values -> rendered Kubernetes YAML -> install or upgrade
```

For interview purposes, Helm is the bridge between plain Kubernetes manifests and repeatable application delivery.

## What CCPU-51 Adds

The first subtask creates the chart scaffold at:

```text
deploy/helm/cpemon
```

The scaffold includes:

| File | Purpose |
| --- | --- |
| `Chart.yaml` | Defines the chart name, type, chart version, app version, keywords, and maintainer metadata. |
| `values.yaml` | Defines default, environment-neutral configuration. |
| `values-dev.yaml` | Defines safe dev overrides, such as namespace and placeholder image tags. |
| `templates/_helpers.tpl` | Defines reusable template helpers for names, labels, and namespace selection. |
| `templates/NOTES.txt` | Prints human-readable guidance after render/install. |
| `.helmignore` | Excludes local-only files from packaged chart archives. |
| `README.md` | Documents how to render and reason about the chart. |

## Why Start With a Scaffold

It is tempting to immediately template every Deployment and Service.

For learning and migration safety, the chart is built in layers:

```text
scaffold -> values model -> workload templates -> optional platform features -> validation
```

This lets each step answer a clear question:

- What is a Helm chart?
- What should be configurable?
- Which parts of the old YAML become templates?
- Which parts should stay as secret references?
- How do we validate before applying anything?

## Chart.yaml Explained

`Chart.yaml` is chart metadata, not a Kubernetes resource.

Important fields:

- `apiVersion: v2` means Helm 3 chart format.
- `name: cpemon` is the chart package name.
- `type: application` means this chart deploys an application, not a reusable library chart.
- `version` is the chart version.
- `appVersion` is the application version metadata.

The important distinction:

```text
chart version changes when the chart changes
app version changes when the application release changes
image tag is controlled by values
```

## values.yaml Explained

`values.yaml` is the default input model for templates.

For CPEmon it captures:

- image registry and pull secret references
- common labels
- non-secret app config
- Secret names and key references
- workload names, replicas, ports, resources, and probes
- optional features such as ingress, NetworkPolicy, PDB, and ServiceMonitor

The values file should not contain real production secrets.

## values-dev.yaml Explained

`values-dev.yaml` is an environment override.

It currently sets:

```yaml
global:
  namespaceOverride: cpemon
```

and uses `__IMAGE_TAG__` placeholders so the migration remains compatible with the existing raw YAML workflow.

In a real CI/CD pipeline, the image tag would usually be passed with:

```powershell
helm upgrade --install cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml --set workloads.cpemonApi.image.tag=<tag>
```

## _helpers.tpl Explained

`_helpers.tpl` stores reusable template functions.

This avoids repeating label and naming logic in every template. That matters because Kubernetes selectors are sensitive: if a Deployment selector and Service selector drift apart, traffic breaks.

Helpers added in the scaffold:

- `cpemon.name`
- `cpemon.fullname`
- `cpemon.labels`
- `cpemon.namespace`

## Pre-Apply Boundary

Current state:

```text
The chart scaffold exists.
Helm is not installed in the local shell.
The EKS cluster has not been applied.
No Helm release has been installed.
```

So the safe validation goal is static review and later local rendering:

```powershell
helm lint deploy/helm/cpemon
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

These commands do not create cluster resources. They only validate and render manifests locally.

## Interview Framing

A strong explanation is:

> We first migrated infrastructure to Terraform, then prepared EKS platform add-ons, then started packaging CPEmon workloads with Helm. The first Helm task intentionally creates the chart scaffold and values model before templating workloads, so later changes are reviewable and environment-specific configuration is separated from reusable Kubernetes object structure.

