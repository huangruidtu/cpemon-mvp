# CPEmon Helm Chart

This chart packages the CPEmon application workloads for the cloud platform upgrade.

It is the application layer that sits above the EKS infrastructure and platform add-ons:

```text
Terraform AWS/EKS foundation -> Kubernetes platform add-ons -> CPEmon Helm chart
```

## Current Scope

`CCPU-51` creates the chart scaffold:

- `Chart.yaml` defines the chart identity and version.
- `values.yaml` defines the default configuration model.
- `values-dev.yaml` provides safe dev overrides.
- `templates/_helpers.tpl` centralizes names, labels, and namespace logic.
- `templates/NOTES.txt` gives install-time guidance.

The workload templates are intentionally added in later subtasks. This keeps the migration teachable: first understand chart anatomy, then values, then templating.

## Render Commands

When Helm is installed:

```powershell
helm lint deploy/helm/cpemon
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

These commands render locally. They do not create AWS or Kubernetes resources.

## Secrets Boundary

Do not commit production database passwords, HMAC secrets, or image pull credentials into this chart.

This chart should reference Kubernetes Secrets by name and key. The actual Secret objects can come from manual bootstrap, External Secrets Operator, Sealed Secrets, SOPS, or another secret-management story.

## Chart Version vs App Version

`version` in `Chart.yaml` is the Helm package version. Change it when the chart itself changes.

`appVersion` describes the application version being packaged. It is documentation metadata and does not automatically change image tags.

Image tags are controlled through values:

```yaml
workloads:
  cpemonApi:
    image:
      tag: "dev"
```

