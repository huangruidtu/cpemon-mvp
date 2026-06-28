# Crossplane Connection Outputs and App Consumption Runbook

This runbook explains how CPEmon applications should consume infrastructure
outputs created by Crossplane.

## Key Rule

Applications should consume stable platform outputs, not raw provider
implementation details.

```text
Crossplane request -> composed AWS resource -> platform-owned output -> app config
```

## Example

```text
k8s/crossplane/consumption/cpemon-api-infra-outputs-example.yaml
```

The example shows:

* a `ConfigMap` for non-sensitive references such as request names and region
* a placeholder `Secret` shape for values resolved only after live
  reconciliation

The placeholder Secret intentionally does not contain real AWS values.

## ConfigMap vs Secret

Use ConfigMap for:

* request names
* region
* feature flags
* non-sensitive resource identifiers

Use Secret for:

* generated endpoints that are treated as sensitive by policy
* credentials emitted by a provider
* application connection strings

## External Secrets Boundary

External Secrets Operator remains the right tool for secrets sourced from AWS
Secrets Manager and KMS. Crossplane connection secrets are different: they are
outputs of resource reconciliation.

In a production design, the platform can choose one of these models:

| Model | When to use |
| --- | --- |
| Crossplane writes Kubernetes connection Secret directly | Simple in-cluster consumption. |
| Crossplane writes to an external secret store | Stronger central secret lifecycle. |
| ESO reads externally managed secrets | App secrets already live in AWS Secrets Manager. |

## Live Validation Boundary

This repository only documents the consumption model and placeholder shape.
Live values require Crossplane reconciliation against AWS and a verified
connection secret strategy.

## Interview Answer

Say:

```text
I separated resource provisioning from application consumption. Crossplane owns
the managed resource and output generation, while applications consume stable
ConfigMap or Secret references. ESO is still used for externally managed
secrets; Crossplane connection outputs are a separate lifecycle.
```
