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

## Scope

The Terraform foundation starts with:

- Terraform and AWS provider version constraints.
- AWS provider configuration for the `dev` environment.
- S3 remote state configuration.
- DynamoDB state locking configuration.
- Safe example input values.
- Minimal outputs for validation.

The first foundation story does not include:

- EKS cluster provisioning.
- ECR repositories.
- VPC redesign.
- GitHub OIDC IAM roles.
- Reusable Terraform modules.
- Multi-account or multi-region production hardening.

## Learning Goal

The purpose of this structure is to make Terraform state, backend configuration, inputs, outputs, validation, and planning easy to understand before adding larger AWS platform resources.
