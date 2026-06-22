# Dev Argo CD Applications

This directory contains Argo CD `Application` manifests for the CPEmon dev
environment.

Planned Applications:

| Application | Target namespace | Source path or chart |
| --- | --- | --- |
| `cpemon-dev` | `cpemon` | `deploy/helm/cpemon` with `values-dev.yaml` |
| `kafka-dev` | `kafka` | Bitnami Kafka chart `32.4.3` with `k8s/addons/kafka/values.yaml` |
| `monitoring-dev` | `monitoring` | Monitoring add-on boundary |
| `external-secrets-dev` | `security` or controller namespace | External Secrets boundary |
| `policy-security-dev` | `security` | Policy/security add-on boundary |

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
