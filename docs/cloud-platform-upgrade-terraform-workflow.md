# CPEmon Cloud Platform Upgrade - Terraform Workflow

## Purpose

This document explains the Terraform workflow used for the CPEmon Cloud Platform Upgrade.

The goal is not only to make Terraform run successfully. The goal is to understand the operating model: where state lives, why locking exists, what each Terraform command does, and how pull requests should be reviewed before infrastructure is changed.

## Current Foundation

The current Terraform root is:

```text
infra/terraform/envs/dev
```

The `dev` environment uses:

- S3 bucket `cpemon-terraform-state-dev-701573843911` for remote state.
- DynamoDB table `cpemon-terraform-locks-dev` for state locking.
- AWS region `eu-north-1`.
- AWS SSO profile `cpemon-terraform` for local operator access.
- GitHub Actions for formatting and validation.
- A future GitHub OIDC role for automated Terraform plan execution.

## Why Remote State Comes First

Terraform state records the resources Terraform manages and how those resources map to configuration.

Local state is acceptable for a first private experiment, but it becomes risky as soon as the project needs repeatable infrastructure work. If state only exists on one machine, the workflow depends on that machine. If two operators run Terraform without shared locking, they can race and corrupt the expected infrastructure view.

For this upgrade, remote state is introduced before EKS because EKS, IAM, ECR, networking, and later GitOps components will all depend on a stable infrastructure workflow.

## Command Flow

Run commands from:

```bash
cd infra/terraform/envs/dev
```

### Format

```bash
terraform fmt -recursive
```

`terraform fmt` rewrites Terraform files into the standard Terraform style.

In CI, the workflow uses:

```bash
terraform fmt -check -recursive
```

`-check` means CI verifies formatting without changing files.

### Init

```bash
terraform init
```

Normal `terraform init` initializes the configured backend and downloads providers.

In this project, normal `terraform init` connects to:

- S3 remote state.
- DynamoDB state lock table.
- The HashiCorp AWS provider registry.

For CI validation, the workflow uses:

```bash
terraform init -backend=false
```

This downloads and initializes provider metadata without connecting to the S3 backend or DynamoDB table. That makes validation possible before GitHub OIDC AWS access is configured.

Use this after backend settings change:

```bash
terraform init -reconfigure
```

`-reconfigure` tells Terraform to re-read the backend configuration instead of reusing cached backend settings.

### Validate

```bash
terraform validate
```

`terraform validate` checks that the Terraform configuration is syntactically valid and matches provider schemas.

Validation does not decide whether the infrastructure change is safe. It only proves the configuration can be understood by Terraform.

### Plan

```bash
terraform plan -var-file="terraform.tfvars"
```

`terraform plan` compares desired configuration with current state and shows intended changes.

Read the plan carefully:

- `to add`: new resources Terraform wants to create.
- `to change`: existing resources Terraform wants to modify.
- `to destroy`: existing resources Terraform wants to delete.

Destroy actions deserve extra review. They may be correct, but they are the highest-risk part of a plan.

In CI, the future plan job will use:

```bash
terraform plan -input=false -no-color -var-file="terraform.tfvars.example"
```

`-input=false` prevents CI from waiting for interactive input.

`-no-color` makes logs easier to read in GitHub Actions.

### Apply

```bash
terraform apply
```

`terraform apply` performs the changes.

This repository does not currently run apply from GitHub Actions. Apply should remain a deliberate operator action until the project has stronger branch protection, OIDC role scoping, review rules, and environment controls.

## Inputs

Committed example input file:

```text
terraform.tfvars.example
```

Local private input file:

```text
terraform.tfvars
```

`terraform.tfvars` is ignored by Git because it can contain machine-specific or private values.

The current example inputs are safe to commit because they contain only project, environment, region, and profile values.

## Remote State And Locking

The backend is configured in:

```text
infra/terraform/envs/dev/backend.tf
```

State is stored in S3:

```text
s3://cpemon-terraform-state-dev-701573843911/cpemon/dev/terraform.tfstate
```

DynamoDB locking uses:

```text
cpemon-terraform-locks-dev
```

The lock table uses `LockID` as the partition key.

Locking matters because Terraform is not safe to run concurrently against the same state. A lock prevents two operators or automation jobs from applying changes at the same time.

## Backend Troubleshooting

### Backend Configuration Changed

If the backend bucket, key, region, profile, or lock table changes, run:

```bash
terraform init -reconfigure
```

This refreshes Terraform's local backend metadata.

### Authentication Fails

Refresh the AWS SSO login:

```bash
aws sso login --profile cpemon-terraform
aws sts get-caller-identity --profile cpemon-terraform
```

The caller identity should show the expected AWS account and an assumed role for the `cpemon-terraform` user.

### Lock Is Stuck

If a Terraform run crashes while holding a lock, Terraform may report that the state is locked.

First confirm that no Terraform process is still running.

Then use the lock ID from the Terraform error:

```bash
terraform force-unlock <LOCK_ID>
```

Do not force-unlock if another real Terraform operation is still running.

## GitHub Actions Behavior

The workflow is defined in:

```text
.github/workflows/terraform.yml
```

Current active gate:

- Checkout repository.
- Install Terraform.
- Check formatting.
- Initialize Terraform without the remote backend.
- Validate the configuration.

Future AWS-backed gate:

- Configure short-lived AWS credentials through GitHub OIDC.
- Initialize the real S3 backend.
- Generate a Terraform plan for review.

The future plan job depends on the repository secret:

```text
CPEMON_TERRAFORM_ROLE_ARN
```

This secret should contain an AWS role ARN, not long-lived access keys.

## Review Checklist

Before approving a Terraform pull request, review:

- Does `terraform fmt -check` pass?
- Does `terraform validate` pass?
- Does the plan show expected resources only?
- Are there any unexpected `to destroy` actions?
- Are IAM permissions scoped to the task?
- Are private values kept out of Git?
- Is the state backend still pointing to the intended environment?

## Interview Story

The CPEmon MVP started as a YAML-first Kubernetes project. The cloud platform upgrade introduces Terraform before EKS because infrastructure changes need a repeatable, reviewable workflow.

The important lesson is the workflow, not just the tooling:

- Terraform gives infrastructure as code.
- S3 remote state gives shared infrastructure memory.
- DynamoDB locking protects concurrent changes.
- Pull request validation catches syntax and formatting issues early.
- Plan review makes infrastructure changes visible before execution.
- GitHub OIDC will later replace long-lived CI credentials with short-lived AWS role assumptions.

This creates a foundation for EKS, ECR, GitOps, and platform security work without jumping straight into cluster creation.
