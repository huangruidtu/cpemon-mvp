# Dev Argo CD Applications

This directory will contain Argo CD `Application` manifests for the CPEmon dev
environment.

Planned Applications:

| Application | Target namespace | Source path or chart |
| --- | --- | --- |
| `cpemon-dev` | `cpemon` | `deploy/helm/cpemon` with `values-dev.yaml` |
| `kafka-dev` | `kafka` | Kafka add-on Helm values from `k8s/addons/kafka` |
| `monitoring-dev` | `monitoring` | Monitoring add-on boundary |
| `external-secrets-dev` | `security` or controller namespace | External Secrets boundary |
| `policy-security-dev` | `security` | Policy/security add-on boundary |

This story starts with plain Application manifests. A root app-of-apps
Application is intentionally deferred.

