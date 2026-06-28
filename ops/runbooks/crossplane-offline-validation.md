# Crossplane Offline Validation Runbook

This runbook explains the repository-level offline validation for the Crossplane
developer self-service story.

## Entry Point

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-story.ps1
```

The script validates:

* Terraform/Crossplane ownership boundary docs
* Crossplane Argo CD installation wiring
* AWS Provider and IRSA manifests
* platform API conventions
* S3, DynamoDB, and ECR XRDs and Compositions
* developer request layout
* Argo CD provider/API/request wiring
* Kyverno guardrails
* app consumption documentation

## Why Offline Validation

The local machine may not have an EKS cluster, Crossplane CRDs, AWS credentials,
or IAM roles available. Offline validation proves that the repository contract
is complete and internally consistent without creating cloud resources.

## What It Does Not Prove

Offline validation does not prove:

* Crossplane controller health
* provider package installation health
* IRSA trust policy correctness
* AWS resource creation
* connection secret emission
* Kyverno live admission behavior

Those checks belong to live validation after the platform is installed.

## Interview Answer

Say:

```text
I split validation into offline and live stages. Offline checks prove the GitOps
manifests, platform API contracts, guardrails, runbooks, and examples are
present and consistent. Live validation then proves controller health, IRSA,
AWS reconciliation, and admission behavior.
```
