# Story 2 Interview Q&A: Terraform Remote State

## 1. Why did you introduce Terraform remote state before provisioning EKS?

**Answer**

Remote state is the foundation for repeatable infrastructure work. Before creating larger resources like EKS, IAM, ECR, and GitOps foundations, the project needed shared Terraform state and locking. Without remote state, infrastructure knowledge lives on one machine. Without locking, two Terraform operations can race against the same state.

In CPEmon, state is stored in S3 and locking uses DynamoDB.

**Project evidence**

- `infra/terraform/envs/dev/backend.tf`
- `docs/cloud-platform-upgrade-terraform-workflow.md`
- `docs/knowledge/terraform-remote-state-workflow.md`

## 2. What is Terraform state?

**Answer**

Terraform state is Terraform's memory of the resources it manages and their mapping to real cloud resources. For example, state can record that `module.ecr_repositories.aws_ecr_repository.this["cpemon-api"]` maps to the AWS ECR repository named `cpemon-api`.

Terraform configuration says what should exist. State says what Terraform currently knows it manages.

**Deep follow-up**

Why can Terraform try to create a resource that already exists?

**Strong response**

Because existing cloud resources are not automatically in Terraform state. If a repository already exists in AWS but has never been imported, Terraform sees it as desired in configuration but absent from state, so the plan shows `+ create`. The fix is `terraform import`.

## 3. What does remote state solve?

**Answer**

Remote state gives the team shared infrastructure memory. It allows Terraform runs from different machines or CI to use the same state file. In this project, S3 stores the state and DynamoDB provides locking.

**Deep follow-up**

Can you use local state for a real project?

**Strong response**

Local state is fine for a throwaway personal experiment. It becomes risky once the infrastructure matters, multiple operators exist, or CI needs to run plan. Remote state is the safer default for team or long-lived infrastructure.

## 4. Why is state locking important?

**Answer**

Terraform is not safe to run concurrently against the same state. If two applies happen at the same time, each might read stale state and write conflicting updates. Locking prevents concurrent state mutations.

In CPEmon, the DynamoDB lock table protects the S3 state file.

**Deep follow-up**

What do you do if a lock is stuck?

**Strong response**

First confirm no Terraform operation is still running. Then use the lock ID from the error with `terraform force-unlock <LOCK_ID>`. Force unlock should be treated carefully because unlocking a real active run can corrupt workflow assumptions.

## 5. What is the difference between validate, plan, and apply?

**Answer**

`terraform validate` checks that Terraform can understand the configuration and provider schema. It does not say whether the change is safe.

`terraform plan` compares desired configuration with state and real infrastructure, then shows what Terraform intends to add, change, or destroy.

`terraform apply` performs the changes.

The main review value is in the plan. Destroy actions or unexpected adds should be inspected before apply.

## 6. Why does CI use `terraform init -backend=false`?

**Answer**

For lightweight CI validation, the workflow only needs providers and syntax checks. It does not need to contact the real S3 backend or take a DynamoDB lock. `terraform init -backend=false` allows validation without AWS access.

Later, a stricter CI plan job can use GitHub OIDC to assume an AWS role and run against the real backend.

## 7. What happened when AWS SSO expired?

**Answer**

Terraform could not refresh backend credentials and failed while trying to access the S3 backend. The fix was to refresh AWS SSO:

```bash
aws sso login --profile cpemon-terraform
```

Then `terraform init -reconfigure` successfully reconnected to the backend.

**Deep follow-up**

Why does that matter in an interview?

**Strong response**

It shows that infrastructure tooling depends on identity and credential flows, not just code. Understanding how Terraform talks to S3, DynamoDB, AWS providers, and SSO helps debug real platform failures.
