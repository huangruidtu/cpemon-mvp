# CPEmon CI Security Gateways

This document captures the current CI/CD security boundary for the Cloud Platform Upgrade ECR and GitOps story.

For the reusable mental model behind this workflow, see [ECR, GitHub OIDC, Terraform, and GitHub Actions](knowledge/ecr-github-oidc-terraform-actions.md).

## Enabled Now

### GitHub OIDC for AWS access

GitHub Actions must assume an AWS IAM role through OIDC. The image publishing workflow does not use long-lived AWS access keys.

Required GitHub secret:

```text
CPEMON_ECR_PUSH_ROLE_ARN
```

The Terraform output `github_ecr_push_role_arn` provides the value after the IAM role is created or imported.

### Least-privilege ECR push permissions

The ECR push role is limited to the three CPEmon service repositories:

- `acs-ingest`
- `cpemon-api`
- `cpemon-writer`

The role can request an ECR authorization token globally, because AWS requires `ecr:GetAuthorizationToken` to use `Resource: "*"`. Push and repository read actions are restricted to the three repository ARNs.

### Docker image build and push

`.github/workflows/docker-ecr.yml` builds and pushes the three service images to ECR:

- `docker/Dockerfile.acs-ingest`
- `docker/Dockerfile.cpemon-api`
- `docker/Dockerfile.cpemon-writer`

Tag behavior:

- Release tag push, such as `v0.1.0`: publishes `latest` and the release tag.
- Manual dispatch: publishes `latest` and `manual-<short-sha>`.

## Deferred

The following checks are intentionally postponed until the project has the relevant runtime and chart surfaces ready:

- GitOps rollout or rollback workflow after image publish.
- Trivy image vulnerability scan before ECR push.
- Trivy filesystem scan.
- Trivy secret scan.
- Trivy IaC scan for Terraform and Kubernetes manifests.
- Critical-vulnerability failure policy.
- Rendered Helm manifest checks.

`kubeconform` and `kube-linter` are not part of the current scope because the project is still YAML-first and Helm is not available yet.

The Kubernetes service manifests already reference the three ECR repositories with a `__IMAGE_TAG__` placeholder. The next GitOps story should decide whether image tags are updated by Kustomize, a manifest-rendering script, Argo CD Image Updater, Flux image automation, or a small GitHub Actions commit-back workflow.

## Existing ECR Repositories

The AWS account already has private ECR repositories for the three service images. Import them into Terraform before applying the ECR module:

```bash
cd infra/terraform/envs/dev
terraform import 'module.ecr_repositories.aws_ecr_repository.this["acs-ingest"]' acs-ingest
terraform import 'module.ecr_repositories.aws_ecr_repository.this["cpemon-api"]' cpemon-api
terraform import 'module.ecr_repositories.aws_ecr_repository.this["cpemon-writer"]' cpemon-writer
```

If the IAM role already exists, import it as well:

```bash
terraform import 'module.github_ecr_push_role.aws_iam_role.this' cpemon-ci-github-role
```

If the ECR push policy already exists, import it with its policy ARN before applying.
