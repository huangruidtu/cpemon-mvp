# Story 3 Interview Q&A: ECR, GitHub OIDC, and Image Publishing

## 1. What problem does CCPU-3 solve?

**Answer**

CCPU-3 creates the foundation for publishing CPEmon service images to AWS ECR securely. It brings the three existing ECR repositories under Terraform management, creates a GitHub Actions OIDC IAM role, attaches a least-privilege ECR push policy, and refactors the Docker image publishing workflow to avoid long-lived AWS keys.

**Project evidence**

- `infra/terraform/modules/ecr_repositories`
- `infra/terraform/modules/github_ecr_push_role`
- `.github/workflows/docker-ecr.yml`
- `docs/ci-security-gateways.md`
- `docs/knowledge/ecr-github-oidc-terraform-actions.md`

## 2. Why use GitHub OIDC instead of AWS access keys in GitHub Secrets?

**Answer**

Long-lived AWS keys in GitHub Secrets increase risk because they can leak, require rotation, and often have broad permissions. With GitHub OIDC, the workflow receives a short-lived identity token from GitHub, exchanges it with AWS STS, and gets temporary credentials for a tightly scoped IAM role.

GitHub stores only the role ARN, not AWS access keys.

**Interview-ready answer**

Previously, CI systems often stored long-lived AWS access keys in GitHub Secrets. In this project, GitHub Actions uses OIDC to receive temporary AWS credentials from STS. The IAM trust policy restricts which repository and branch or tag can assume the role, and the attached policy only allows pushing images to the required ECR repositories.

## 3. What is the complete OIDC flow?

**Answer**

The workflow starts and requests a GitHub OIDC token. GitHub issues a short-lived JWT. The `aws-actions/configure-aws-credentials` action sends that JWT to AWS STS using `AssumeRoleWithWebIdentity`. AWS checks the role's trust policy, including the token audience and subject. If the token matches, STS returns temporary AWS credentials. The workflow then logs in to ECR and pushes Docker images.

**Deep follow-up**

Which token claim is most important for scoping GitHub access?

**Strong response**

The `sub` claim. It identifies the GitHub repository and ref, such as `repo:huangruidtu/cpemon-mvp:ref:refs/heads/main` or `repo:huangruidtu/cpemon-mvp:ref:refs/tags/v*`.

## 4. What is the difference between an IAM trust policy and a permission policy?

**Answer**

The trust policy answers: who can assume this role?

The permission policy answers: what can this role do after it is assumed?

For this project, the trust policy allows GitHub's OIDC provider to assume the role only when the token audience is `sts.amazonaws.com` and the subject matches the CPEmon repo/ref pattern. The permission policy allows ECR push actions only on the three CPEmon repositories.

## 5. Why does `ecr:GetAuthorizationToken` use `Resource: "*"`?

**Answer**

AWS requires `ecr:GetAuthorizationToken` to use `Resource: "*"`. It cannot be scoped to a single ECR repository ARN the same way push actions can. To keep least privilege clear, the policy separates `GetAuthorizationToken` into its own statement, while repository-specific push actions are scoped to the three repository ARNs.

## 6. Why did existing ECR repositories require `terraform import`?

**Answer**

The repositories already existed in AWS, but Terraform state did not know about them. Terraform only manages resources that are in its state. Without import, `terraform plan` showed the three repositories as `+ create`, even though they were already present.

After importing:

```bash
terraform import -var-file="terraform.tfvars.example" 'module.ecr_repositories.aws_ecr_repository.this[\"acs-ingest\"]' acs-ingest
```

Terraform state mapped the module resource address to the existing AWS repository.

**Deep follow-up**

Why was PowerShell tricky here?

**Strong response**

Terraform resource addresses for `for_each` keys require quoted strings, such as `["acs-ingest"]`. In PowerShell, the inner quotes can be stripped when passed to Terraform, so the command must escape them as `[\"acs-ingest\"]`.

## 7. How did you know import succeeded?

**Answer**

Terraform printed `Import successful` for all three repositories. Then `terraform plan` no longer showed the ECR repositories as `+ create`. It only showed in-place tag updates for the imported repositories, plus creation of the IAM role, policy, and attachment.

That means the repositories were now in Terraform state and safely managed by Terraform.

## 8. Why avoid relying on `latest` image tags?

**Answer**

`latest` is mutable and ambiguous. It does not tell you which commit or release is running, and it can make rollbacks or incident debugging harder.

A stronger strategy is to use immutable tags:

- Release tags such as `v1.2.3` for formal releases.
- Commit SHA tags for branch or PR builds.
- Optional metadata tags for convenience, but not as the deployment source of truth.

**Follow-up backlog**

This is intentionally left for a later pipeline hardening story. The current CCPU-3 workflow still publishes `latest`, but the future direction is to avoid using `latest` as the deployment reference.

## 9. What should a multi-stage CI/CD model look like later?

**Answer**

A future pipeline should have different gates for different promotion levels.

For feature or hotfix PRs into the upgrade branch:

- Fast linting.
- Go build/test.
- Terraform validate.
- Docker build validation.

For PRs toward main or release:

- Stricter security gates.
- Trivy image/filesystem/IaC scans.
- Rendered Helm manifest validation.
- kubeconform/kube-linter.
- Terraform plan review.
- Immutable image tags.
- Optional GitOps promotion or rollout checks.

The idea is to keep fast feedback during development and stricter controls near release.

## 10. How did you validate the Terraform-managed AWS state?

**Answer**

The existing ECR repositories, the GitHub OIDC IAM role, the ECR push IAM policy, and the role-policy attachment were all present in Terraform state. The final validation command was:

```bash
terraform plan -input=false -no-color -var-file="terraform.tfvars.example"
```

The expected result was:

```text
No changes. Your infrastructure matches the configuration.
```

That result means Terraform configuration, Terraform state, and real AWS infrastructure are aligned.

**Deep follow-up**

Why is `terraform apply` alone not enough as the final proof?

**Strong response**

`terraform apply` can succeed after making changes, but a clean follow-up `terraform plan` proves there is no remaining drift. In this story, the clean plan confirmed that the imported ECR repositories, imported IAM role, IAM policy, trust policy, and policy attachment all matched the code.

## 11. What IAM permission issues did you hit, and what did you learn?

**Answer**

The Terraform bootstrap permission set started with only backend access, so each AWS operation revealed the next least-privilege permission required:

- ECR import needed `ecr:DescribeRepositories`.
- ECR tag management needed `ecr:TagResource`.
- Creating/importing IAM resources needed role and policy read/write permissions scoped to `cpemon-ci-github-role` and `cpemon-ci-github-role-ecr-push`.
- Importing a role needed read/list IAM actions such as `iam:GetRole`, `iam:ListRolePolicies`, and `iam:ListAttachedRolePolicies`.
- Updating the OIDC trust policy needed `iam:UpdateAssumeRolePolicy`.

The key lesson was to add exact permissions for the exact Terraform operation instead of giving broad admin access.

**Deep follow-up**

What was the subtle IAM policy bug?

**Strong response**

`iam:ListAttachedRolePolicies` was accidentally grouped with `iam:AttachRolePolicy` under an `iam:PolicyARN` condition. That condition is valid for restricting which policy can be attached, but list operations do not use that same condition key. The fix was to separate read/list permissions from the conditional attach permission.

## 12. How did you validate the GitHub Actions image push?

**Answer**

The workflow was validated by pushing a test version tag:

```bash
git tag -a v0.0.0-ccpu3-test -m "CCPU-3 ECR push validation"
git push origin v0.0.0-ccpu3-test
```

That triggered the `Build & Push Docker images to ECR` workflow through the tag push path. The successful run was:

```text
GitHub Actions run: 27871227136
Trigger: push tag v0.0.0-ccpu3-test
Commit: f6c80047ad7db3029359798d6f2433d966592bf2
Result: success
```

All three matrix jobs succeeded:

- `acs-ingest`
- `cpemon-api`
- `cpemon-writer`

Each job completed the same critical path:

- Configure AWS credentials through GitHub OIDC.
- Login to Amazon ECR.
- Build Docker image.
- Push Docker image.

**Deep follow-up**

Why use a tag instead of manually dispatching from the upgrade branch?

**Strong response**

The IAM trust policy intentionally allowed only `main` and `refs/tags/v*`. A manual dispatch from the upgrade branch failed because its OIDC `sub` claim did not match the trusted refs. Instead of widening the trust policy for convenience, the validation used a test `v*` tag. That proved the secure release path without granting the upgrade branch AWS publishing access.

## 13. What incident drill came out of the first failed run?

**Answer**

The first validation attempt used `workflow_dispatch` from the upgrade branch and failed at:

```text
Configure AWS credentials through GitHub OIDC
```

The error was:

```text
Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

The root cause was an OIDC trust-policy mismatch. The GitHub token subject represented the upgrade branch, but the IAM role only trusted `main` and `v*` tags.

The resolution was to trigger the workflow through a trusted tag ref instead of broadening the trust policy.

**Interview-ready answer**

I intentionally kept the AWS trust policy narrow. A manual workflow dispatch from the upgrade branch failed because that branch was not trusted by the role's OIDC `sub` condition. I treated that as an incident drill, confirmed the failure was caused by trust-policy scope, and reran the workflow through a trusted version tag. The tag run succeeded and pushed all three images to ECR.

## 14. What remains after CCPU-3?

**Answer**

The CCPU-3 ECR/OIDC image publishing foundation is complete. Later hardening work should move into follow-up stories:

- Replace `latest` as a deployment source of truth with immutable tags.
- Build a multi-stage CI/CD model for feature, upgrade, main, and release paths.
- Add Trivy image/filesystem/secret/IaC scans.
- Add Helm-rendered manifest checks after Helm exists.
- Add GitOps rollout and rollback automation.
