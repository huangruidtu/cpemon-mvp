# Final Interview Pack

## Project Summary

CPEmon is a telco-style monitoring system upgraded into a platform engineering
case study. The upgrade moves the project from static Kubernetes manifests
toward an EKS-oriented platform with infrastructure as code, GitOps delivery,
Kafka event flow, progressive delivery, observability, governance, cost
visibility, developer self-service, and AI-assisted troubleshooting boundaries.

## Resume Bullets

* Upgraded a Kubernetes monitoring MVP into an EKS-oriented platform using
  Terraform, Helm, Argo CD, Kafka, External Secrets, Argo Rollouts, Prometheus,
  Kyverno, OpenCost, Crossplane, and K8sGPT.
* Refactored the ingest/write path toward Kafka-backed event publishing and
  consumer processing with validation scripts, runbooks, and operational
  dashboards.
* Designed GitOps release workflows with Helm packaging, Argo CD Applications,
  Prometheus-backed canary analysis, and documented rollback paths.
* Added platform governance and developer enablement through Kyverno policies,
  OpenCost visibility, Crossplane self-service claims, and service catalog
  metadata.
* Produced an interview-ready evidence pack with architecture diagrams, ADRs,
  runbooks, validation scripts, demo scripts, and live validation boundaries.

## STAR Story: Migration

Situation: The MVP was Kubernetes-first but not packaged as a modern platform.

Task: Turn it into a platform upgrade that could be explained and validated.

Action: Introduced Terraform boundaries, Helm packaging, GitOps, Kafka,
observability, governance, Crossplane, and K8sGPT in staged stories.

Result: The repo now reads as a platform engineering case study with evidence
behind each decision.

## Strong Answers

### Why not let Crossplane replace Terraform?

Terraform owns the high-blast-radius foundation. Crossplane exposes selected
developer-facing resources after the cluster exists. That split avoids two
reconcilers fighting over the same infrastructure.

### Why use K8sGPT carefully?

K8sGPT is useful for early hypotheses, but it is not a source of truth. I kept
it read-only and documented verification with events, logs, Prometheus, Argo CD,
and rollout status.

### What is the most important GitOps decision?

Separate application delivery from platform add-ons, use conservative sync
policies first, and document rollback and drift boundaries.

### What is the main limitation?

The repo contains a validated framework. Some claims require live EKS, AWS,
Argo CD, Kafka, Crossplane, and K8sGPT environments before they can be described
as runtime-proven.

## Future Roadmap

* Backstage portal connected to service metadata.
* KEDA for event-driven autoscaling after HPA baseline.
* Karpenter for node provisioning optimization.
* SBOM, Cosign, and SLSA provenance.
* Alert enrichment with K8sGPT after privacy and quality review.
* Production hardening with stronger network policy and disaster recovery.
