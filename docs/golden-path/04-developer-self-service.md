# Developer Self-Service Path

## Goal

Explain how a developer uses the platform without needing unrestricted cloud
access.

## Developer Requests

Developers can work with:

* Helm values for service configuration;
* ExternalSecret references for runtime secrets;
* Kafka topic conventions;
* Crossplane claims for selected resources;
* Kyverno policies for guardrail feedback;
* OpenCost for cost visibility;
* K8sGPT for diagnostic hints.

## Secret Boundary

Real secret values stay outside Git.

```text
AWS Secrets Manager + KMS = secret value owner
External Secrets Operator = sync bridge
Helm chart = reference template
application = runtime consumer
```

## Crossplane Boundary

Terraform still owns the EKS foundation. Crossplane exposes selected
application-level platform APIs:

* S3 bucket claims
* DynamoDB table claims
* ECR repository claims

Developers request intent; platform engineers own the composition.

## New Service Checklist

1. Add service code and Dockerfile.
2. Add Helm values and templates.
3. Add ServiceMonitor and metrics.
4. Add resource requests and labels.
5. Add ExternalSecret references if needed.
6. Add Kafka topics or consumers if needed.
7. Add Argo CD Application wiring.
8. Add runbook and validation script.
9. Add service catalog metadata.
10. Add interview notes for the design decision.

## Interview Framing

```text
The platform gives developers paved roads, not unrestricted cloud access.
They can deploy services, consume secrets safely, request approved
infrastructure, and troubleshoot with documented signals.
```
