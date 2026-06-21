# Story 12: Helm CPEmon Application

## Q1: What is the goal of CCPU-6?

The goal is to migrate CPEmon application Kubernetes manifests from raw YAML toward a reusable Helm chart.

This makes application deployment more repeatable, configurable across environments, easier to validate before apply, and better prepared for future GitOps.

## Q2: Where does Helm fit in the cloud platform upgrade?

Terraform owns AWS infrastructure such as VPC, subnets, EKS, IAM, and node groups.

Kubernetes platform add-ons prepare shared cluster capabilities such as namespaces, metrics-server, AWS Load Balancer Controller, StorageClass checks, and NetworkPolicy baseline.

Helm packages the CPEmon application workloads that run on top of that platform.

## Q3: What did CCPU-51 add?

It added the CPEmon chart scaffold under:

```text
deploy/helm/cpemon
```

The scaffold includes chart metadata, default values, dev overrides, helper templates, install notes, and chart README documentation.

## Q4: What is `Chart.yaml`?

`Chart.yaml` is Helm chart metadata.

It defines the chart name, type, chart version, app version, keywords, and maintainers. It is not submitted to Kubernetes as a resource.

## Q5: What is the difference between chart `version` and `appVersion`?

`version` is the Helm package version. It changes when the chart changes.

`appVersion` describes the application version being packaged. It is metadata and does not automatically set container image tags.

Image tags should be controlled through values or CI/CD inputs.

## Q6: What is `values.yaml`?

`values.yaml` is the default configuration input for chart templates.

For CPEmon, it captures image settings, replicas, ports, resource requests/limits, probes, non-secret app config, secret reference names, and feature flags for optional resources.

## Q7: Why add `values-dev.yaml`?

`values-dev.yaml` keeps development overrides separate from default chart behavior.

This is important because the same chart should be usable across environments, while each environment can override namespace, tags, replicas, endpoints, or optional features.

## Q7.1: What did CCPU-52 change in the values model?

It made the chart values detailed enough for future templates.

The model now separates global image defaults, app config, database/secret references, shared defaults, per-workload settings, scheduling controls, and optional platform features.

## Q7.2: Why use `global.imageTag` instead of repeating the tag under every workload?

Most services in one deployment are usually built from the same commit or release.

A global image tag lets CI/CD set one value for the whole application release. Workload-specific tags remain possible for exceptions, but the normal path avoids duplication.

## Q7.3: How should a template resolve an image tag in this chart?

The intended logic is:

```text
if workload.image.tag is set, use it
otherwise use global.imageTag
```

That lets `values-dev.yaml` set one placeholder tag for all workloads while still allowing one service to be overridden later.

## Q7.4: What is Helm values precedence?

Helm starts with the chart's `values.yaml`, then merges each `-f` values file in order, then applies CLI overrides such as `--set`.

Higher-precedence values replace lower-precedence values.

For example:

```powershell
helm template cpemon deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml --set global.imageTag=sha-abc123
```

uses `sha-abc123` because `--set` has higher precedence than both files.

## Q7.5: Why split `env` and `secretEnv`?

Plain `env` is for non-secret values that can be committed, such as `HTTP_ADDR`.

`secretEnv` is for environment variables sourced from Kubernetes Secrets, such as `DB_DSN` and `HMAC_SECRET`. The chart stores only Secret names and keys, not secret values.

## Q7.6: Why have a `defaults` section?

The three CPEmon workloads share service ports, probes, resources, and pod metadata patterns.

A `defaults` section keeps those shared settings in one place and lets each workload override only what is different. This reduces YAML duplication and makes future review easier.

## Q7.7: Why keep `values-dev.yaml` small?

Environment override files should show only what differs from the default model.

If `values-dev.yaml` repeats the whole chart, it becomes another copy of the chart configuration and loses the benefit of Helm's merge model.

## Q7.8: What is `values.schema.json` in a Helm chart?

`values.schema.json` is a JSON Schema file that Helm can use to validate chart values.

It helps catch common mistakes before deployment, such as invalid image pull policies, wrong replica count types, or malformed secret environment variable definitions.

It is especially useful in migration work because it turns the values model into a documented contract rather than an informal YAML convention.

## Q8: Why not put real passwords into Helm values?

Helm values are usually committed, rendered in CI logs, and stored in release history unless additional precautions are used.

Real secrets should be managed through Kubernetes Secrets, External Secrets Operator, SOPS, Sealed Secrets, or another secret-management approach. The chart should reference secret names and keys rather than storing secret values directly.

## Q9: What is `_helpers.tpl`?

`_helpers.tpl` is a place for reusable Helm template helpers.

It commonly defines name, fullname, labels, selector labels, and namespace helpers. This prevents repeated template logic and reduces selector/label drift.

## Q10: Why create the scaffold before templating Deployments?

It keeps the migration understandable and lower risk.

The sequence is:

```text
chart scaffold -> values model -> workloads -> services/config/secrets -> optional features -> validation
```

That sequence is easier to review and explain in an interview than a single large rewrite.

## Q11: What command checks a Helm chart locally?

```powershell
helm lint deploy/helm/cpemon
```

This checks chart structure and common template problems.

## Q12: What command renders manifests without applying them?

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

This prints Kubernetes YAML locally. It does not create resources in the cluster.

## Q13: What is a Helm release?

A Helm release is an installed instance of a chart in a Kubernetes namespace.

The same chart can be installed multiple times as different releases, often with different values.

## Q14: Why is Helm useful for migration projects?

Migration projects often have repeated YAML with small environment differences.

Helm moves those differences into values, while keeping the Kubernetes object structure in reusable templates. That improves repeatability, reviewability, and future GitOps compatibility.

## Q15: What is the current validation boundary?

At this point, the chart can be linted and rendered locally.

The EKS cluster has not been applied in this local workflow, so live `helm upgrade --install` validation is intentionally deferred.

## Q16: What did CCPU-53 add?

`CCPU-53` added the first real workload template for the CPEmon Helm chart.

The chart now renders one Deployment and one Service for each enabled workload in `.Values.workloads`:

```text
cpemon-api
acs-ingest
cpemon-writer
```

This turns the values model from CCPU-52 into Kubernetes manifests.

## Q17: Why use one reusable workload template instead of three separate YAML files?

The three CPEmon services have the same Kubernetes shape: Deployment, Service, image settings, ports, probes, resources, labels, and optional scheduling rules.

The differences are workload-specific values such as name, component, repository, replicas, and env vars.

Using one reusable template reduces copy-paste drift and makes future changes easier to review.

## Q18: Why keep the old `app` label?

Existing Kubernetes resources already depend on it.

For example, ServiceMonitor and PDB selectors use labels such as:

```yaml
app: cpemon-api
```

The Helm chart keeps that compatibility label and adds recommended `app.kubernetes.io/*` labels for clearer production-style ownership.

## Q19: Why are Deployment selectors designed carefully?

Deployment selectors are immutable after the Deployment is created.

If a selector changes, Kubernetes cannot simply patch the existing Deployment. In practice, this can force a delete and recreate.

So the chart uses stable selector labels: app name, Helm release instance, and component.

## Q20: How does the chart resolve container images?

The chart combines:

```text
global.imageRegistry
workload.image.repository
workload.image.tag or global.imageTag
```

This allows normal releases to use one global image tag while still allowing per-workload overrides.

## Q21: What security improvement did CCPU-53 make compared with the old raw YAML?

The template renders sensitive runtime inputs through Kubernetes Secret references:

```yaml
valueFrom:
  secretKeyRef:
    name: cpemon-db
    key: dsn
```

The chart commits Secret names and keys, not real secret values.

## Q22: What commands validated CCPU-53?

```powershell
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

The chart rendered successfully. `helm lint` reported only an informational icon recommendation and no chart failure.

## Q23: How would you summarize CCPU-53 in an interview?

I converted the CPEmon Helm chart from a values-only scaffold into a real application rendering layer. The chart now templates Deployments and Services for `cpemon-api`, `acs-ingest`, and `cpemon-writer` from a shared workload model. I kept backward-compatible `app` labels for monitoring selectors, added Kubernetes recommended labels, resolved images from global and workload-specific values, and moved sensitive env vars to Secret references. This made the application deployment more repeatable and safer while preserving the behavior of the original raw manifests.

## Q24: What did CCPU-54 add?

`CCPU-54` added the ConfigMap and secret-reference boundary for the CPEmon Helm chart.

The chart now renders a `cpemon-app-config` ConfigMap for non-secret runtime settings, while DB and HMAC values remain external Secret references.

## Q25: What belongs in a ConfigMap?

A ConfigMap should hold non-sensitive runtime configuration.

In this chart, examples are:

```text
HTTP_ADDR
GRAFANA_HOME_URL
GRAFANA_SN_DASHBOARD_URL_TEMPLATE
KIBANA_HOME_URL
KIBANA_SN_LOGS_URL_TEMPLATE
```

These values change application behavior but are not credentials.

## Q26: What belongs in a Secret?

A Secret should hold sensitive runtime data such as passwords, tokens, HMAC keys, and connection strings that include credentials.

In this chart:

```text
DB_DSN -> cpemon-db / dsn
HMAC_SECRET -> cpemon-acs-hmac / hmac-secret
```

The chart references those names and keys but does not store the real secret values.

## Q27: Why not put production secrets directly in Helm values?

Helm values are often committed to Git, printed in CI logs, included in rendered manifests, and stored in Helm release history.

That makes them a poor place for real production passwords or keys.

For production, real secret material should come from a secret-management flow such as External Secrets Operator, SOPS, Sealed Secrets, AWS Secrets Manager integration, or a controlled bootstrap process.

## Q28: What is the difference between Helm values and a ConfigMap?

Helm values are chart inputs used at render time.

A ConfigMap is a Kubernetes object that exists in the cluster and is read by Pods at runtime.

In this chart, Helm values define the desired config, and the template renders those values into a ConfigMap.

## Q29: How do workloads consume ConfigMap values?

Workloads consume non-secret settings through `configMapKeyRef`:

```yaml
valueFrom:
  configMapKeyRef:
    name: cpemon-app-config
    key: GRAFANA_HOME_URL
```

This keeps the Deployment template reusable and moves environment-specific non-secret values into the ConfigMap.

## Q30: Which Kubernetes Secrets must exist before installing this chart?

The chart expects these Secrets to exist:

```text
cpemon-ecr-regcred
cpemon-db key dsn
cpemon-acs-hmac key hmac-secret
```

`cpemon-ecr-regcred` is used for pulling private ECR images. `cpemon-db` provides `DB_DSN`. `cpemon-acs-hmac` provides the ACS webhook HMAC secret.

## Q31: How would you summarize CCPU-54 in an interview?

I separated non-secret application configuration from secret material in the Helm chart. Non-sensitive runtime values now render into a chart-owned ConfigMap and workloads consume them through `configMapKeyRef`. Sensitive values such as `DB_DSN` and `HMAC_SECRET` remain external Kubernetes Secret references, so the chart documents required Secret names and keys without committing credentials. This makes the chart safer, easier to configure per environment, and closer to a production deployment model.
