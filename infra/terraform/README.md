# CPEmon Terraform Foundation

This directory contains the Terraform foundation for the CPEmon Cloud Platform Upgrade.

The first implementation is intentionally simple. It starts with one environment root and does not introduce reusable Terraform modules yet. Modules can be added later when EKS, ECR, IAM, or shared platform resources create enough repetition to justify the abstraction.

## Directory Layout

```text
infra/
  terraform/
    README.md
    envs/
      dev/
        backend.tf
        versions.tf
        providers.tf
        variables.tf
        outputs.tf
        terraform.tfvars.example
```

## Environment Root

`infra/terraform/envs/dev` is the Terraform environment root for the first cloud platform upgrade environment.

Run Terraform commands from that directory:

```bash
cd infra/terraform/envs/dev
terraform init
terraform fmt
terraform validate
terraform plan
```

Before committing Terraform changes, run:

```bash
terraform fmt -recursive
terraform validate
```

`terraform fmt` rewrites Terraform files into the standard style. `terraform validate` checks that the configuration is syntactically valid and matches the provider schema after initialization.

## Scope

The Terraform foundation starts with:

- Terraform and AWS provider version constraints.
- AWS provider configuration for the `dev` environment.
- S3 remote state configuration.
- DynamoDB state locking configuration.
- Safe example input values.
- Minimal outputs for validation.

## Remote State Locking Decision

The `dev` backend uses the classic Terraform S3 remote state pattern:

- S3 stores the shared state file.
- DynamoDB provides state locking through the `LockID` partition key.
- The `cpemon-terraform` AWS SSO profile is used for local Terraform access.

Current Terraform versions warn that the S3 backend `dynamodb_table` argument is deprecated in favor of S3-native lock files. For this foundation step, the DynamoDB lock table is intentionally kept because the goal is to practice and document the traditional remote-state locking model that is still common in existing Terraform estates.

If this project later chooses to remove the warning and use the newer S3 lock-file model, the backend can be migrated separately after the state workflow is stable.

## GitHub Actions Workflow

The repository includes `.github/workflows/terraform.yml` for Terraform pull-request checks.

The workflow has two jobs:

- `validate` runs `terraform fmt -check -recursive`, `terraform init -backend=false`, and `terraform validate`. This job does not need AWS credentials because it skips the remote backend.
- `plan` runs `terraform init` and `terraform plan` against the real dev backend only when the repository secret `CPEMON_TERRAFORM_ROLE_ARN` is configured.

The plan job is intentionally OIDC-based. GitHub should assume a short-lived AWS role instead of storing long-lived AWS access keys in repository secrets.

The plan command uses `terraform.tfvars.example` so CI has safe, committed input values. The private `terraform.tfvars` file remains local-only.

The first foundation story does not include:

- EKS cluster provisioning.
- ECR repositories.
- VPC redesign.
- GitHub OIDC IAM roles.
- Reusable Terraform modules.
- Multi-account or multi-region production hardening.

## Learning Goal

The purpose of this structure is to make Terraform state, backend configuration, inputs, outputs, validation, and planning easy to understand before adding larger AWS platform resources.
