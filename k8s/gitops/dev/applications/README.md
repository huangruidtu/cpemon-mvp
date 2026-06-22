# Dev Argo CD Applications

This directory contains Argo CD `Application` manifests for the CPEmon dev
environment.

Planned Applications:

| Application | Target namespace | Source path or chart |
| --- | --- | --- |
| `cpemon-dev` | `cpemon` | `deploy/helm/cpemon` with `values-dev.yaml` |
| `kafka-dev` | `kafka` | Bitnami Kafka chart `32.4.3` with `k8s/addons/kafka/values.yaml` |
| `monitoring-dev` | `monitoring` | kube-prometheus-stack chart `86.3.2` with `k8s/monitoring/kube-prometheus-stack-values.yaml` |
| `external-secrets-dev` | `external-secrets` | External Secrets Operator chart `2.6.0` with `k8s/addons/external-secrets/values.yaml` |
| `policy-security-dev` | `cpemon` | CPEmon baseline NetworkPolicy candidate from `k8s/netpol/baseline` |
| `argo-rollouts-dev` | `argo-rollouts` | Argo Rollouts chart `2.41.0` with `k8s/addons/argo-rollouts/values.yaml` |
| `kyverno-dev` | `kyverno` | Kyverno chart `3.8.1` with `k8s/addons/kyverno/values.yaml` |
| `kyverno-policies-dev` | `kyverno` | CPEmon Kyverno policies from `k8s/policies/kyverno` |

This story starts with plain Application manifests. A root app-of-apps
Application is intentionally deferred.

## `cpemon-dev`

`cpemon-dev.yaml` deploys the CPEmon Helm chart:

```text
repoURL:        https://github.com/huangruidtu/cpemon-mvp.git
targetRevision: HEAD
path:           deploy/helm/cpemon
values:         values-dev.yaml
destination:    https://kubernetes.default.svc / cpemon
project:        cpemon
```

The Application uses manual sync by default. Automated sync, prune, and
self-heal are introduced as a separate operational decision so the first
Application remains easy to inspect.

## `kafka-dev`

`kafka-dev.yaml` deploys the Kafka platform Helm chart:

```text
chart repo:     registry-1.docker.io/bitnamicharts
chart:          kafka
chart version:  32.4.3
values repo:    https://github.com/huangruidtu/cpemon-mvp.git
values file:    k8s/addons/kafka/values.yaml
destination:    https://kubernetes.default.svc / kafka
project:        cpemon
```

The Application uses Argo CD multiple sources because the chart is external
and the values file is versioned in the CPEmon repository.

## `monitoring-dev`

`monitoring-dev.yaml` deploys the monitoring platform stack:

```text
chart repo:     ghcr.io/prometheus-community/charts
chart:          kube-prometheus-stack
chart version:  86.3.2
release:        kps
values repo:    https://github.com/huangruidtu/cpemon-mvp.git
values file:    k8s/monitoring/kube-prometheus-stack-values.yaml
destination:    https://kubernetes.default.svc / monitoring
project:        cpemon
```

The Application owns the monitoring control plane. CPEmon-specific
ServiceMonitor, PrometheusRule, and Grafana dashboard resources depend on the
CRDs and selectors created by this stack.

## `external-secrets-dev`

`external-secrets-dev.yaml` deploys the External Secrets Operator controller:

```text
chart repo:     https://charts.external-secrets.io
chart:          external-secrets
chart version:  2.6.0
release:        external-secrets
values repo:    https://github.com/huangruidtu/cpemon-mvp.git
values file:    k8s/addons/external-secrets/values.yaml
destination:    https://kubernetes.default.svc / external-secrets
project:        cpemon
```

This Application installs the controller and CRDs. Real secret values stay in
AWS Secrets Manager, not Git.

## `policy-security-dev`

`policy-security-dev.yaml` deploys the staged CPEmon NetworkPolicy baseline:

```text
repoURL:        https://github.com/huangruidtu/cpemon-mvp.git
targetRevision: HEAD
path:           k8s/netpol/baseline
destination:    https://kubernetes.default.svc / cpemon
project:        cpemon
```

Kyverno remains deferred. The current repository has NetworkPolicy candidate
manifests and validation docs, but it does not yet have a pinned Kyverno chart,
values file, policy package, or live validation plan.

## `argo-rollouts-dev`

`argo-rollouts-dev.yaml` deploys the progressive delivery controller:

```text
chart repo:     https://argoproj.github.io/argo-helm
chart:          argo-rollouts
chart version:  2.41.0
release:        argo-rollouts
values repo:    https://github.com/huangruidtu/cpemon-mvp.git
values file:    k8s/addons/argo-rollouts/values.yaml
destination:    https://kubernetes.default.svc / argo-rollouts
project:        cpemon
```

The controller is platform delivery infrastructure. CPEmon application charts
can later define `Rollout`, stable Service, canary Service, and analysis
resources, but the controller itself stays outside the application chart.

## `kyverno-dev`

`kyverno-dev.yaml` deploys the Kyverno governance control plane:

```text
chart repo:     https://kyverno.github.io/kyverno/
chart:          kyverno
chart version:  3.8.1
release:        kyverno
values repo:    https://github.com/huangruidtu/cpemon-mvp.git
values file:    k8s/addons/kyverno/values.yaml
destination:    https://kubernetes.default.svc / kyverno
project:        cpemon
```

Kyverno is platform governance infrastructure. This Application installs the
controllers and CRDs. The concrete CPEmon policies are added separately so the
control plane and policy package can be reviewed independently.

## `kyverno-policies-dev`

`kyverno-policies-dev.yaml` deploys the CPEmon Kyverno policy package:

```text
repoURL:        https://github.com/huangruidtu/cpemon-mvp.git
targetRevision: HEAD
path:           k8s/policies/kyverno
directory:      recurse true
destination:    https://kubernetes.default.svc / kyverno
project:        cpemon
```

The first policy requires CPU and memory requests and limits for Pods in the
`cpemon` namespace. It is intentionally deployed after `kyverno-dev` so the
controller and CRDs exist before `ClusterPolicy` resources are synced.
