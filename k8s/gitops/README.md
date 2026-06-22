# GitOps Layout

This directory contains Argo CD desired-state entry points for CPEmon.

## Layout Decision

Story 11 uses two layers:

```text
k8s/addons/argocd/
  namespace.yaml
  projects/
    cpemon-project.yaml

k8s/gitops/
  dev/
    applications/
      README.md
      cpemon-dev.yaml
      kafka-dev.yaml
      monitoring-dev.yaml
```

Bootstrap resources stay under `k8s/addons/argocd` because they install and
prepare Argo CD itself.

Application resources stay under `k8s/gitops/<environment>/applications`
because they are the objects Argo CD reconciles after the control plane exists.

## App-Of-Apps Decision

This story starts with plain Argo CD `Application` manifests instead of an
app-of-apps root Application.

Why:

* there is one learning environment, `dev`
* the number of Applications is still small
* plain manifests are easier to inspect, validate, and explain
* app-of-apps can be added later when environment promotion or many apps make a
  root Application useful

## Source Mapping

CPEmon Helm chart:

```text
deploy/helm/cpemon
deploy/helm/cpemon/values-dev.yaml
```

Kafka add-on values:

```text
k8s/addons/kafka/values.yaml
```

Argo CD project boundary:

```text
k8s/addons/argocd/projects/cpemon-project.yaml
```

Argo CD Application manifests:

```text
k8s/gitops/dev/applications
```

First application:

```text
k8s/gitops/dev/applications/cpemon-dev.yaml
```

`cpemon-dev` reconciles the CPEmon Helm chart from
`deploy/helm/cpemon` with `values-dev.yaml` into the `cpemon` namespace.

`kafka-dev` reconciles the Bitnami Kafka Helm chart version `32.4.3` with the
repository values file `k8s/addons/kafka/values.yaml` into the `kafka`
namespace.

`monitoring-dev` reconciles kube-prometheus-stack chart version `86.3.2` with
the repository values file `k8s/monitoring/kube-prometheus-stack-values.yaml`
into the `monitoring` namespace.

## Interview Framing

GitOps layout is architecture. It tells an interviewer where desired state
lives, which files are bootstrap-only, which files are reconciled by Argo CD,
and how Helm chart paths map to deployed applications.
