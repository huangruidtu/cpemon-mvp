# Terraform Remote State and Workflow

This note captures the reusable Terraform lessons from the CPEmon Cloud Platform Upgrade foundation work.

## Mental Model

Terraform configuration is the desired infrastructure.

Terraform state is Terraform's memory of what it manages.

Remote state is shared memory.

Locking prevents two people or automation jobs from editing that memory at the same time.

In one sentence:

> Terraform is not just a command that creates cloud resources; it is a workflow for making infrastructure changes reviewable, repeatable, and safely coordinated through state and plans.

## Why State Matters

Terraform does not only read `.tf` files. It also reads state.

State records mappings like:

```text
module.ecr_repositories.aws_ecr_repository.this["cpemon-api"]
  -> AWS ECR repository cpemon-api
```

Without state, Terraform cannot reliably know whether a resource already exists, was changed outside Terraform, or should be updated.

That is why an existing AWS resource must be imported before Terraform manages it:

```bash
terraform import 'module.ecr_repositories.aws_ecr_repository.this["cpemon-api"]' cpemon-api
```

After import, Terraform state knows:

```text
This Terraform address maps to that existing AWS resource.
```

## Local State vs Remote State

Local state is acceptable for a private first experiment. It becomes risky when:

- More than one machine needs to run Terraform.
- CI needs to run plan.
- The project needs a recoverable infrastructure history.
- Multiple resources depend on the same foundation.

Remote state solves the shared-memory problem.

In CPEmon, the dev backend uses:

```text
S3 bucket: cpemon-terraform-state-dev-701573843911
State key: cpemon/dev/terraform.tfstate
Region: eu-north-1
DynamoDB lock table: cpemon-terraform-locks-dev
AWS profile: cpemon-terraform
```

S3 stores the state file. DynamoDB stores the lock.

## Why Locking Exists

Terraform is not safe to run concurrently against the same state.

If two operators run `terraform apply` at the same time, both may read the same old state, make different assumptions, and write conflicting updates.

Locking prevents this by allowing only one active Terraform operation to hold the state lock.

If a run crashes while holding the lock, Terraform may report a stuck lock. The safe recovery path is:

1. Confirm no real Terraform process is still running.
2. Read the lock ID from the Terraform error.
3. Run:

```bash
terraform force-unlock <LOCK_ID>
```

Do not force-unlock a real active operation.

## Command Responsibilities

Each Terraform command answers a different question.

### `terraform fmt`

Question:

```text
Are the Terraform files formatted in the standard style?
```

Local:

```bash
terraform fmt -recursive
```

CI:

```bash
terraform fmt -check -recursive
```

`-check` verifies formatting without changing files.

### `terraform init`

Question:

```text
Can Terraform initialize providers, modules, and backend settings?
```

Normal local initialization:

```bash
terraform init
```

When backend settings changed:

```bash
terraform init -reconfigure
```

For CI validation that should not contact the real backend:

```bash
terraform init -backend=false
```

One practical lesson from CPEmon: local `.terraform` metadata can cache backend settings. If Terraform keeps trying to contact the S3 backend during a backend-disabled validation, use a clean validation directory or reinitialize carefully.

### `terraform validate`

Question:

```text
Can Terraform understand this configuration and provider schema?
```

Command:

```bash
terraform validate
```

Validation proves the configuration is syntactically and structurally valid. It does not prove the change is safe.

### `terraform plan`

Question:

```text
What will Terraform do if applied?
```

Command:

```bash
terraform plan -input=false -no-color -var-file="terraform.tfvars.example"
```

Read these carefully:

- `to add`: Terraform wants to create resources.
- `to change`: Terraform wants to modify resources.
- `to destroy`: Terraform wants to delete resources.

Unexpected destroy actions deserve the highest review.

In CCPU-3, the plan initially showed the three ECR repositories as `+ create`. That did not mean the repositories were missing in AWS. It meant Terraform state did not know about the existing repositories yet.

### `terraform apply`

Question:

```text
Should Terraform perform this plan against real infrastructure?
```

Command:

```bash
terraform apply
```

In this project, apply remains a deliberate operator action. CI can validate and plan, but automatic apply should wait until branch protection, environment controls, and role scoping are stronger.

## Inputs and Secrets

Committed example inputs:

```text
terraform.tfvars.example
```

Private local inputs:

```text
terraform.tfvars
```

`terraform.tfvars` is ignored by Git because it can contain local or private values.

The principle:

> Commit safe examples and structure; keep private operational values out of Git.

## CI Behavior

Terraform CI usually has two levels.

Level 1: no AWS credentials required

```text
checkout
setup Terraform
terraform fmt -check
terraform init -backend=false
terraform validate
```

This proves the configuration is readable and structurally valid.

Level 2: AWS-backed plan

```text
configure short-lived AWS credentials through GitHub OIDC
terraform init
terraform plan
```

This proves Terraform can compare desired configuration with real state.

For CPEmon, the future AWS-backed CI plan role is stored as:

```text
CPEMON_TERRAFORM_ROLE_ARN
```

That should be a role ARN, not an AWS access key.

## Backend Troubleshooting

If SSO expired:

```bash
aws sso login --profile cpemon-terraform
aws sts get-caller-identity --profile cpemon-terraform
```

Then reinitialize:

```bash
terraform init -reconfigure
```

If backend configuration changed:

```bash
terraform init -reconfigure
```

If validation should avoid backend access:

```bash
terraform init -backend=false
```

If cached backend metadata gets in the way, validate from a clean copy that excludes `backend.tf` and `.terraform`.

## Review Checklist

Before approving Terraform changes, ask:

- Does formatting pass?
- Does validation pass?
- Does the plan show only expected resources?
- Are any destroy actions expected and justified?
- Are IAM permissions scoped to the task?
- Are secrets kept out of Git?
- Is the backend pointing to the intended environment?
- Are existing resources imported before Terraform tries to recreate them?
- Does the state address match the resource name and module path?

## Interview-Ready Summary

> Terraform is more than writing cloud resources in code. The important operating model is state, locking, plan review, and controlled apply. In CPEmon, remote state lives in S3 and DynamoDB provides locking so infrastructure changes can be coordinated safely. CI can run formatting and validation without AWS access, while an AWS-backed plan can later use GitHub OIDC. Existing resources such as ECR repositories must be imported into state before Terraform can manage them safely.

## Commands to Remember

```bash
cd infra/terraform/envs/dev
terraform init -reconfigure
terraform fmt -recursive
terraform validate
terraform plan -input=false -no-color -var-file="terraform.tfvars.example"
```

Import existing ECR repositories:

```bash
terraform import 'module.ecr_repositories.aws_ecr_repository.this["acs-ingest"]' acs-ingest
terraform import 'module.ecr_repositories.aws_ecr_repository.this["cpemon-api"]' cpemon-api
terraform import 'module.ecr_repositories.aws_ecr_repository.this["cpemon-writer"]' cpemon-writer
```

Refresh AWS SSO:

```bash
aws sso login --profile cpemon-terraform
aws sts get-caller-identity --profile cpemon-terraform
```
