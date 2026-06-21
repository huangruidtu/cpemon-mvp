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

## Q32: What did CCPU-55 add?

`CCPU-55` added optional platform feature templates around the CPEmon Helm chart:

```text
Ingress
ServiceMonitor
PodDisruptionBudget
NetworkPolicy
```

They are controlled by values flags and disabled by default.

## Q33: Why should optional platform features be controlled by values?

Not every environment has the same platform add-ons.

A local or early dev cluster may not have an ingress controller, Prometheus Operator CRDs, or NetworkPolicy enforcement. Values flags let the same chart render only the integrations that the target environment supports.

## Q34: Why is ServiceMonitor disabled by default?

`ServiceMonitor` is not a native Kubernetes kind.

It is a CRD installed by Prometheus Operator or kube-prometheus-stack. If the CRD does not exist in the cluster, applying a ServiceMonitor manifest will fail.

## Q35: Why is Ingress disabled by default?

Ingress requires an ingress controller.

The Kubernetes Ingress object only describes desired routing. Something like ingress-nginx or AWS Load Balancer Controller must actually watch the Ingress and create routing behavior.

## Q36: Why not create a PDB for every workload?

A PDB should match the workload's replica and availability model.

For a single-replica workload, `minAvailable: 1` can block voluntary disruptions because Kubernetes cannot evict the only pod while keeping one available.

In this chart, `cpemon-api` and `acs-ingest` get PDBs by default when PDB is enabled. `cpemon-writer` is disabled in the PDB map because it currently has one replica.

## Q37: What does the NetworkPolicy template do?

When enabled, it renders a baseline egress posture:

```text
default deny egress
allow DNS egress
allow core app egress to MySQL
optionally allow monitoring/logging egress
```

This makes allowed traffic explicit instead of assuming every pod can connect everywhere.

## Q38: What is the main risk with enabling NetworkPolicy?

If required traffic is not allowed, applications can lose DNS, database, metrics, logging, or external connectivity.

NetworkPolicy should be enabled after reviewing required traffic paths and confirming that the cluster CNI or policy engine enforces NetworkPolicy as expected.

## Q39: How did you validate CCPU-55?

I validated two render paths.

First, default dev rendering:

```powershell
helm lint deploy/helm/cpemon -f deploy/helm/cpemon/values-dev.yaml
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

That kept optional platform resources disabled.

Second, enabled rendering:

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml --set ingress.enabled=true --set serviceMonitor.enabled=true --set pdb.enabled=true --set networkPolicy.enabled=true
```

That rendered the optional resources successfully.

## Q40: How would you summarize CCPU-55 in an interview?

I added optional platform integration templates to the Helm chart while keeping conservative defaults. The chart can now render Ingress, ServiceMonitor, PDB, and NetworkPolicy resources when the target cluster supports them. These features are disabled by default because they depend on platform add-ons or operational assumptions. This keeps dev rendering safe while preparing the chart for production-style Kubernetes environments.

## Q41: What did CCPU-56 add?

`CCPU-56` added repeatable Makefile targets for Helm validation:

```text
helm-check
helm-cpemon-lint
helm-cpemon-template
helm-cpemon-validate
```

These targets wrap the chart's `helm lint` and `helm template` commands.

## Q42: Why add Makefile targets if the Helm commands are simple?

Makefile targets reduce human error and make validation repeatable.

Instead of every developer typing a long command with the right chart path, namespace, release name, and values file, the team can run:

```powershell
make helm-cpemon-validate
```

That is easier to remember and easier to reuse in CI.

## Q43: What does `helm lint` catch?

`helm lint` checks chart structure, template syntax, values schema rules, and common chart mistakes.

It does not prove the application will run, but it catches many errors before a chart is installed or reviewed.

## Q44: What does `helm template` catch?

`helm template` renders the chart into plain Kubernetes YAML.

That lets the team inspect selectors, labels, image names, env vars, ConfigMap references, Secret references, Ingress paths, PDBs, NetworkPolicies, and ServiceMonitors before applying anything.

## Q45: Why is `helm template` useful before GitOps?

GitOps tools like Argo CD ultimately apply rendered Kubernetes desired state.

If a chart cannot render cleanly, GitOps cannot sync it cleanly. Rendering locally gives fast feedback before the chart reaches the GitOps controller.

## Q46: Why is live `helm install` still deferred?

Live install needs a real cluster, required namespaces, platform add-ons, image pull access, and runtime Secrets.

At this stage, the goal is pre-apply validation. The chart can be linted and rendered locally, but installing it belongs after the EKS cluster and required dependencies exist.

## Q47: How can the Makefile work if `helm` is installed but not on PATH?

The Makefile lets the operator override the Helm binary:

```powershell
make helm-cpemon-validate HELM="C:/path/to/helm.exe"
```

This keeps the target useful even when a newly installed tool is not visible to an already-open shell.

## Q48: How would you summarize CCPU-56 in an interview?

I added Makefile targets that make Helm validation repeatable. The project now has one command for linting and rendering the CPEmon chart against the dev values file. The targets fail clearly if Helm is missing and support overriding the Helm binary path. This turns manual chart checks into a team workflow that can later be reused in CI or GitOps validation.

## Q49: What did CCPU-57 add?

`CCPU-57` added operator-facing documentation for the CPEmon Helm chart.

The main artifact is:

```text
ops/runbooks/helm-cpemon-application.md
```

It explains validation, render review, future install, post-install checks, rollback, troubleshooting, and the migration decision from raw YAML to Helm.

## Q50: What is the difference between a chart README and a runbook?

A chart README explains what the chart contains.

A runbook explains how to operate it.

For this project, the README documents chart structure and values. The runbook documents the workflow: validate, render, inspect, install later, check, troubleshoot, and roll back.

## Q51: Why describe pre-apply and post-apply separately?

Because the current project can validate and render the chart locally, but the live EKS install is not available yet.

Pre-apply validation includes `helm lint`, `helm template`, values review, rendered YAML inspection, and documenting required Secrets.

Post-apply validation includes `helm status`, rollout checks, Service checks, Ingress checks, ServiceMonitor checks, NetworkPolicy checks, and application health checks.

## Q52: How does Helm prepare the application for Argo CD?

Argo CD can use a Helm chart as a source of desired Kubernetes manifests.

By moving CPEmon into a chart, the project gives Argo CD a clean application package to render and sync later. Values files can represent environment-specific configuration while Git remains the source of truth.

## Q53: How would you explain Helm versus Terraform in this project?

Terraform provisions cloud infrastructure such as VPC, subnets, EKS, IAM, and ECR.

Helm packages Kubernetes application resources such as Deployments, Services, ConfigMaps, and optional application-level integrations.

They operate at different layers. Terraform creates the platform foundation. Helm packages what runs on top of Kubernetes.

## Q54: Why not stay with raw Kubernetes YAML?

Raw YAML is fine for a small MVP because it is explicit and easy to inspect.

As the project grows, raw YAML becomes harder to reuse across environments. Image tags, replicas, resources, config, secret references, Ingress, monitoring, PDBs, and NetworkPolicies all need controlled variation.

Helm keeps the stable Kubernetes object structure in templates and moves environment differences into values.

## Q55: What remains before a real Helm install?

The project still needs:

- a live EKS cluster
- kubeconfig access
- the `cpemon` namespace
- required Secrets
- image tags that exist in ECR
- platform add-ons before optional features are enabled

Until then, the honest validation boundary is local lint and render.

## Q56: How would you summarize CCPU-57 in an interview?

I documented the operational workflow for the CPEmon Helm chart. The runbook explains how to validate and render the chart now, what to inspect in the generated manifests, what prerequisites are needed before live install, how to check a future release, and how to roll back. I also captured the migration decision: Terraform owns infrastructure, Helm packages the application, and the chart prepares CPEmon for future Argo CD GitOps.

## Interview Storyline: 90-Second Version

CPEmon started as a raw Kubernetes YAML MVP, which was useful because every object was explicit and easy to learn from.

As the platform upgrade moved toward EKS and future GitOps, raw YAML became harder to scale across environments. Image tags, replicas, resources, non-secret config, secret references, Ingress, monitoring, PDBs, and NetworkPolicies all needed controlled variation.

I introduced a Helm chart under `deploy/helm/cpemon` to package the application layer. Terraform still owns cloud infrastructure, and Kubernetes platform add-ons still provide cluster capabilities. Helm owns the reusable application rendering layer.

I built the chart in stages: scaffold, values model, workload templates, ConfigMap and Secret references, optional platform integrations, Makefile validation targets, and runbook documentation. I kept Secrets as references rather than committing secret material, and I kept optional platform features disabled by default because they depend on cluster add-ons.

The chart is now validated with `helm lint` and `helm template` before any live install. That gives fast feedback and prepares the application for a future Argo CD workflow, where Git will be the source of truth and Argo CD can render and sync the Helm chart into the cluster.

## Interview Storyline: STAR Format

Situation:

CPEmon had working Kubernetes manifests, but they were raw YAML and environment-specific values were embedded directly in repeated files.

Task:

The application needed a reusable packaging model that could support EKS, CI-provided image tags, safer secret handling, optional platform integrations, and future GitOps.

Action:

I created a Helm chart with a structured values model, reusable helpers, workload templates for the three services, ConfigMap and Secret reference handling, optional Ingress/ServiceMonitor/PDB/NetworkPolicy templates, Makefile validation targets, and runbook/interview documentation.

Result:

The application can now be rendered consistently with one chart and environment-specific values. The team can validate the chart locally before install, avoid committing real secrets, and later hand the chart to Argo CD for GitOps deployment.

## Helm Mental Model Cheat Sheet

Use this short model when answering fast interview questions:

```text
Chart = package
templates = Kubernetes object patterns
values = environment-specific inputs
helpers = reusable naming/label logic
release = installed instance of a chart
helm lint = chart sanity check
helm template = render without applying
helm upgrade --install = apply or update a release
```

The CPEmon chart maps those concepts to real project files:

```text
Chart.yaml -> package metadata
values.yaml -> default model
values-dev.yaml -> dev overrides
templates/*.yaml -> generated Kubernetes objects
_helpers.tpl -> labels, names, image/env helpers
Makefile -> repeatable validation workflow
runbook -> operator workflow
```

## Helm vs Terraform vs kubectl apply

| Tool | Owns | In this project |
| --- | --- | --- |
| Terraform | Cloud infrastructure lifecycle | VPC, subnets, EKS, IAM, ECR, node groups |
| Helm | Kubernetes application packaging | CPEmon Deployments, Services, ConfigMap, optional app integrations |
| kubectl apply | Direct Kubernetes object apply | useful for raw MVP manifests, dry-runs, and operational checks |
| Argo CD | GitOps reconciliation | future controller that can consume the Helm chart from Git |

Interview framing:

> I avoid using one tool to solve every layer. Terraform provisions the cloud foundation, Helm packages the application for Kubernetes, kubectl is useful for direct inspection and emergency operations, and Argo CD later reconciles desired state from Git.

## Common Helm Render Failures

Q57: What common Helm render failures did you prepare for?

Common failures include:

- missing value
- wrong value type
- bad YAML indentation
- helper name typo
- selector/label mismatch
- invalid image tag or repository
- Secret reference typo
- ConfigMap key mismatch
- optional CRD rendered before the CRD exists

Q58: How do you debug a missing value in Helm?

First render locally with the same values file:

```powershell
helm template cpemon deploy/helm/cpemon -n cpemon -f deploy/helm/cpemon/values-dev.yaml
```

Then check whether the missing field belongs in `values.yaml`, `values-dev.yaml`, or a CLI `--set` override. If it is a stable default, it belongs in `values.yaml`. If it is environment-specific, it belongs in an override file or CI/GitOps input.

Q59: How do you debug a selector mismatch?

Render the Deployment and Service together and compare:

```text
Deployment spec.selector.matchLabels
Pod template metadata.labels
Service spec.selector
```

For CPEmon, the chart uses shared helpers so workload labels and selector labels stay consistent.

Q60: How do you debug a ServiceMonitor that does not scrape anything?

Check three things:

- the ServiceMonitor CRD exists
- the ServiceMonitor selector matches Service labels
- the selected Service has a port named `metrics`

For CPEmon, ServiceMonitor is optional and disabled by default because it requires Prometheus Operator CRDs.

Q61: How do you debug a NetworkPolicy issue?

Start with DNS and database connectivity.

If DNS egress is blocked, almost everything else looks broken. If DB egress is blocked, the app may start but fail runtime operations. The CPEmon NetworkPolicy template explicitly models DNS and core egress so those paths are reviewable before enabling the policy.

## High-Frequency Interview Follow-Ups

Q62: Why did you keep optional features disabled by default?

Because they depend on cluster capabilities that may not exist everywhere.

Ingress needs a controller, ServiceMonitor needs CRDs, NetworkPolicy needs enforcement, and PDBs need a replica model that makes sense. Disabling them by default keeps dev rendering safe.

Q63: Why use Helm values instead of copying per-environment YAML?

Copying YAML creates drift. A later bug fix has to be copied into every environment file.

Helm keeps the object shape in one template and lets values describe environment differences.

Q64: Why not store Secret values in Helm?

Helm values can appear in Git, CI logs, rendered manifests, and Helm release history.

The safer pattern is for the chart to reference Secret names and keys, while real secret material comes from a controlled secret-management workflow.

Q65: What did you validate without a live cluster?

I validated chart structure and rendering:

- `helm lint`
- `helm template`
- values schema checks
- selector and label consistency by rendered output review
- ConfigMap and Secret reference shape
- optional feature rendering with flags enabled

I did not claim live rollout validation because the EKS cluster was not applied.

Q66: What would you validate after live install?

After live install I would check:

- `helm status`
- `helm get manifest`
- Deployment rollout status
- Services and endpoints
- ConfigMap and Secret references
- image pull events
- application health endpoints
- optional Ingress, ServiceMonitor, PDB, and NetworkPolicy behavior

## Personal Practice Prompts

Use these prompts to rehearse without memorizing:

1. Explain why raw YAML was acceptable for the MVP but Helm is better for the upgrade.
2. Walk through how `values.yaml`, `values-dev.yaml`, and `--set global.imageTag=...` merge.
3. Explain why selectors are sensitive and why helpers reduce drift.
4. Explain why `helm template` is valuable before `helm install`.
5. Explain how the chart avoids committing real secrets.
6. Explain why optional platform features are disabled by default.
7. Explain how this Helm chart prepares the project for Argo CD.

## Final Interview Summary

If there is only time for one answer:

> I Helmized CPEmon by turning repeated raw Kubernetes manifests into a reusable application chart. The chart separates stable Kubernetes structure from environment-specific values, uses helpers for stable labels and selectors, keeps non-secret config in a ConfigMap, references Secrets by name/key, and supports optional platform integrations behind values flags. I added Makefile validation so the chart can be linted and rendered before install, and documented the pre-apply boundary honestly because the live EKS cluster was not available yet. This makes the application deployment more repeatable today and prepares it for Argo CD GitOps later.
