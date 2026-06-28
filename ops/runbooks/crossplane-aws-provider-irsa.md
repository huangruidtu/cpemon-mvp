# Crossplane AWS Provider and IRSA Runbook

This runbook documents the AWS Provider authentication boundary for Crossplane.

The CPEmon platform uses IRSA for Crossplane AWS provider authentication. Static AWS access keys are intentionally avoided.

## Manifest Contract

```text
Provider family:       provider-family-aws
Service providers:     provider-aws-s3, provider-aws-dynamodb, provider-aws-ecr
Runtime config:        aws-irsa-runtime
ProviderConfig:        aws-dev-irsa
Credential source:     IRSA
Manifest path:         k8s/crossplane/providers/aws
```

## Why IRSA

IRSA lets the provider controller pod assume an IAM role through the EKS OIDC
provider.

The security model is:

```text
Kubernetes ServiceAccount
  -> annotated with IAM role ARN
  -> EKS OIDC token
  -> AWS STS AssumeRoleWithWebIdentity
  -> temporary AWS credentials
```

This avoids long-lived AWS keys in Kubernetes secrets.

## Required AWS Preparation

Before live provisioning, AWS must have:

* an EKS OIDC provider
* an IAM role for the Crossplane AWS provider
* a trust policy allowing the provider ServiceAccount to assume the role
* least-privilege permissions for the resource classes being exposed

The placeholder role ARN in the manifests must be replaced:

```text
arn:aws:iam::111122223333:role/cpemon-crossplane-provider-aws-dev
```

## Local Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-aws-provider-irsa.ps1
```

Offline validation proves only the manifest contract and documentation. It does
not prove AWS authentication.

## Apply Through GitOps

After `crossplane-dev` is healthy:

```powershell
kubectl apply -f k8s/crossplane/providers/aws/provider-family-aws.yaml
kubectl apply -f k8s/crossplane/providers/aws/provider-services.yaml
kubectl apply -f k8s/crossplane/providers/aws/providerconfig.yaml
```

The Argo CD Application for this path is added in a later subtask.

## Runtime Validation

```powershell
kubectl get providers.pkg.crossplane.io
kubectl describe provider.pkg.crossplane.io provider-family-aws
kubectl describe provider.pkg.crossplane.io provider-aws-s3
kubectl describe provider.pkg.crossplane.io provider-aws-dynamodb
kubectl get providerconfig.aws.upbound.io aws-dev-irsa
kubectl get pods -n crossplane-system
```

A ready provider is not the same as a successful AWS resource creation. Real
AWS validation happens when an S3 or DynamoDB claim reconciles successfully.

## Troubleshooting

If providers are not healthy:

```powershell
kubectl describe provider.pkg.crossplane.io provider-family-aws
kubectl get events -n crossplane-system --sort-by=.lastTimestamp
```

If AWS calls fail:

1. Check the ServiceAccount annotation in the provider runtime config.
2. Check the IAM role trust policy.
3. Check that the EKS OIDC provider exists.
4. Check the IAM permissions for the requested service.
5. Confirm `ProviderConfig` uses `source: IRSA`.

## Interview Notes

The concise answer:

```text
I configured the AWS provider path to use IRSA instead of static AWS keys. The
provider controller assumes an IAM role through the EKS OIDC provider, and the
ProviderConfig uses source IRSA. That keeps credentials short-lived and keeps
the security boundary outside application claims.
```
