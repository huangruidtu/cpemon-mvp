# Local Development and Offline Validation

## Goal

Validate as much of CPEmon as possible without requiring a live EKS cluster.

This is important for portfolio and interview use because the repo should be
reviewable even when the interviewer cannot access your AWS account.

## Required Tools

* Go
* Helm
* kubectl
* PowerShell
* Terraform
* AWS CLI for live AWS workflows
* K8sGPT CLI for live detective-layer demos

## Core Local Checks

```powershell
go test ./...
make helm-cpemon-validate
make k8sgpt-detective-layer-check
make final-portfolio-check
```

## Story-Specific Validation

The repo contains focused validation scripts in `scripts/`.

Examples:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-architecture-docs.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-runbook-adr-interview.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-final-checklist.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-k8sgpt-detective-layer.ps1
```

## Offline Versus Live

Offline validation proves:

* files exist;
* docs are indexed;
* Helm templates render;
* scripts and examples are present;
* architecture decisions are documented.

Live validation proves:

* the cluster accepts manifests;
* Argo CD syncs applications;
* Kafka brokers run;
* Prometheus scrapes metrics;
* Crossplane provisions real AWS resources;
* K8sGPT analyzes real cluster state.

Do not mix those claims in interviews. Say exactly what was validated.
