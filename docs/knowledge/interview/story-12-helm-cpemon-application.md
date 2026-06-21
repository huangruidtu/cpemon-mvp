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

At this point, the chart scaffold can be reviewed and later rendered locally.

The local shell does not currently have Helm installed, and the EKS cluster has not been applied. Therefore live `helm upgrade --install` validation is intentionally deferred.

