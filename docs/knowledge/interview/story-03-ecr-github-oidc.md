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

## 12. What remains before the image publishing story is fully done?

**Answer**

The AWS infrastructure layer is done and verified with a clean Terraform plan. The remaining validation is the runtime CI/CD layer:

- Add the GitHub secret `CPEMON_ECR_PUSH_ROLE_ARN` if it is not already configured.
- Trigger the Docker ECR workflow through a `v*.*.*` tag or manual dispatch.
- Confirm GitHub Actions assumes the role through OIDC.
- Confirm all three Docker images build and push to ECR.
- Confirm ECR shows the expected immutable version tag.

Only after images are successfully pushed to ECR should the image build/push validation subtask be marked done.
