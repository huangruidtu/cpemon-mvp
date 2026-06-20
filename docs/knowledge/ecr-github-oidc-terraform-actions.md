# ECR, GitHub OIDC, Terraform, and GitHub Actions

This note explains the CCPU-3 image publishing foundation: Terraform manages AWS-side resources and permissions, while GitHub Actions uses those resources to build and push Docker images to ECR.

## Mental Model

Terraform creates the road, warehouse, and access control.

GitHub Actions drives on that road every time a workflow runs.

OIDC is the short-lived login mechanism that lets GitHub Actions temporarily assume an AWS role without storing long-lived AWS keys in GitHub.

In one sentence:

> Terraform creates ECR and AWS-side trust/permissions; GitHub Actions uses GitHub OIDC to temporarily assume the AWS role, then logs in to ECR, builds images, and pushes them.

## End-to-End OIDC Flow

The full ECR publishing flow is:

```text
GitHub Actions job starts
  -> workflow requests a GitHub OIDC identity token
  -> GitHub issues a short-lived JWT
  -> aws-actions/configure-aws-credentials sends that JWT to AWS STS
  -> AWS checks the IAM role trust policy
  -> AWS STS returns temporary AWS credentials
  -> GitHub Actions logs in to ECR
  -> workflow builds Docker images
  -> workflow pushes images to ECR
```

The workflow must explicitly allow OIDC token issuance:

```yaml
permissions:
  contents: read
  id-token: write
```

`id-token: write` does not grant write access to the repository. It lets the workflow ask GitHub's OIDC provider for an identity token.

The important claims in that token are:

```text
iss = https://token.actions.githubusercontent.com
aud = sts.amazonaws.com
sub = repo:<github-owner>/<repo-name>:ref:refs/heads/main
```

The `sub` claim is especially important because AWS can use it to restrict role assumption to a specific GitHub repository and branch.

## OIDC vs Long-Lived AWS Secrets

The older pattern stores long-lived AWS credentials in GitHub Secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

That works, but it creates avoidable risk:

- The key can live for a long time.
- If it leaks, the blast radius is high.
- Rotation is manual.
- Permissions often become too broad.
- It is harder to connect usage to a specific workflow identity.

The OIDC pattern stores only the role ARN in GitHub:

```text
CPEMON_ECR_PUSH_ROLE_ARN=arn:aws:iam::<account-id>:role/cpemon-ci-github-role
```

The role ARN is not a password. It only tells the workflow which AWS role it wants to assume. The actual authorization comes from AWS trust policy and IAM policy.

| Topic | Long-lived AWS secret | GitHub OIDC |
| --- | --- | --- |
| Stored in GitHub | AWS access key and secret key | Role ARN only |
| Credential lifetime | Long-lived | Short-lived |
| Rotation | Manual | Mostly avoided |
| Permission model | IAM user or access key | IAM role plus trust policy |
| Recommended for modern CI | No | Yes |

Interview-ready summary:

> Previously, CI systems often used long-lived AWS access keys stored as GitHub Secrets. In this project, the workflow uses GitHub Actions OIDC to receive temporary AWS credentials through STS. The trust policy restricts which repository and branch can assume the role, and the attached IAM policy only allows pushing images to the required ECR repositories.

## What Terraform Owns

Terraform answers:

- What AWS resources should exist?
- Which identity can assume which role?
- What can that role access?
- What is the permission boundary?

For CCPU-3, Terraform owns:

- ECR repositories for `acs-ingest`, `cpemon-api`, and `cpemon-writer`.
- The GitHub Actions ECR push IAM role.
- The role trust policy for GitHub OIDC.
- The least-privilege ECR push IAM policy.
- The role-policy attachment.
- Outputs such as ECR repository URLs and the GitHub Actions role ARN.

In this project, the ECR repositories already existed in AWS before the Terraform module was added. That means they must be imported into Terraform state before `terraform apply`, otherwise Terraform will try to create repositories that already exist.

```bash
cd infra/terraform/envs/dev
terraform import 'module.ecr_repositories.aws_ecr_repository.this["acs-ingest"]' acs-ingest
terraform import 'module.ecr_repositories.aws_ecr_repository.this["cpemon-api"]' cpemon-api
terraform import 'module.ecr_repositories.aws_ecr_repository.this["cpemon-writer"]' cpemon-writer
```

After import, run:

```bash
terraform plan -input=false -no-color -var-file="terraform.tfvars.example"
```

The plan should no longer show the three ECR repositories as `+ create`.

## What GitHub Actions Owns

GitHub Actions answers:

- When should a pipeline run?
- Which image tag should be produced?
- Which Dockerfiles should be built?
- Should the images be pushed to ECR?

For CCPU-3, `.github/workflows/docker-ecr.yml` owns:

- Checking out the repository.
- Requesting AWS credentials through GitHub OIDC.
- Logging in to ECR.
- Building three Docker images:
  - `docker/Dockerfile.acs-ingest`
  - `docker/Dockerfile.cpemon-api`
  - `docker/Dockerfile.cpemon-writer`
- Pushing `latest` and a version tag to ECR.

The key workflow difference from the long-lived secret pattern is:

```yaml
permissions:
  contents: read
  id-token: write

steps:
  - name: Configure AWS credentials through GitHub OIDC
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.CPEMON_ECR_PUSH_ROLE_ARN }}
      aws-region: eu-north-1
```

The workflow does not use:

```yaml
aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

## IAM Trust Policy vs Permission Policy

There are two different IAM questions:

1. Who is allowed to assume this role?
2. What can the role do after it is assumed?

The trust policy answers the first question. For GitHub OIDC, it should trust `token.actions.githubusercontent.com` and restrict claims such as `aud` and `sub`.

Example shape:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": [
        "repo:huangruidtu/cpemon-mvp:ref:refs/heads/main",
        "repo:huangruidtu/cpemon-mvp:ref:refs/tags/v*"
      ]
    }
  }
}
```

The permission policy answers the second question. In this project, the role should only be able to push images to:

- `acs-ingest`
- `cpemon-api`
- `cpemon-writer`

Most ECR push actions can be scoped to repository ARNs. `ecr:GetAuthorizationToken` is different: AWS requires it to use `Resource: "*"`, so it is kept in a separate statement.

## CCPU-3 Completion Standard

CCPU-3 is not complete just because `terraform validate` passes. It has three layers.

### Layer 1: Code Is Ready

- Terraform modules are written.
- GitHub Actions workflow is written.
- Documentation is written.
- `terraform fmt` passes.
- `terraform validate` passes.

### Layer 2: AWS State Is Correct

- Existing ECR repositories are imported into Terraform state.
- Terraform plan does not try to recreate existing repositories.
- The GitHub OIDC role exists.
- The least-privilege ECR push policy is attached.
- The GitHub OIDC provider exists or is already available in the account.

### Layer 3: Pipeline Works End to End

- The workflow assumes the AWS role through OIDC.
- ECR login succeeds.
- Docker build succeeds for all three services.
- Docker push succeeds.
- ECR shows the expected image tags.

Only after Layer 3 is successful should the image push validation subtask be considered done.

## Common Failure Modes

- The GitHub secret `CPEMON_ECR_PUSH_ROLE_ARN` is missing or points to the wrong role.
- The IAM trust policy `sub` does not match the repository, branch, or tag that triggered the workflow.
- The trust policy `aud` is not `sts.amazonaws.com`.
- The AWS region in the workflow does not match the ECR registry region.
- `ecr:GetAuthorizationToken` is missing.
- Push permissions are scoped to the wrong repository ARN.
- The ECR repository name does not match the Docker image name.
- Terraform state does not know about existing ECR repositories, so `plan` tries to create them.

## Commands to Remember

Terraform validation:

```bash
cd infra/terraform/envs/dev
terraform init -reconfigure
terraform fmt -recursive
terraform validate
terraform plan -input=false -no-color -var-file="terraform.tfvars.example"
```

ECR repository import:

```bash
terraform import 'module.ecr_repositories.aws_ecr_repository.this["acs-ingest"]' acs-ingest
terraform import 'module.ecr_repositories.aws_ecr_repository.this["cpemon-api"]' cpemon-api
terraform import 'module.ecr_repositories.aws_ecr_repository.this["cpemon-writer"]' cpemon-writer
```

AWS-side check:

```bash
aws ecr describe-repositories \
  --repository-names acs-ingest cpemon-api cpemon-writer \
  --region eu-north-1
```

## References

- [GitHub Docs: Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM: OIDC Federation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)
- [AWS IAM: Create a Role for OpenID Connect Federation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html)
- [AWS CLI: assume-role-with-web-identity](https://docs.aws.amazon.com/cli/latest/reference/sts/assume-role-with-web-identity.html)
