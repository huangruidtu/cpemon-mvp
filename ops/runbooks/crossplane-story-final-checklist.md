# Crossplane Developer Self-Service Final Checklist

This checklist closes the CPEmon Crossplane developer self-service story.

## Implemented Framework

| Area | Artifact |
| --- | --- |
| Terraform boundary | `ADR/cloud-platform-upgrade-crossplane-terraform-boundary.md` |
| Crossplane install | `k8s/gitops/dev/applications/crossplane-dev.yaml` |
| AWS provider and IRSA | `k8s/crossplane/providers/aws` |
| Platform API contract | `k8s/crossplane/platform-api-conventions.md` |
| S3 platform API | `k8s/crossplane/platform-apis/s3` |
| DynamoDB platform API | `k8s/crossplane/platform-apis/dynamodb` |
| ECR platform API | `k8s/crossplane/platform-apis/ecr` |
| Developer requests | `k8s/crossplane/claims/dev/cpemon-api` |
| Argo CD wiring | `k8s/gitops/dev/applications/crossplane-providers-dev.yaml` |
| Kyverno guardrails | `k8s/policies/kyverno/crossplane/require-crossplane-request-guardrails.yaml` |
| App consumption model | `k8s/crossplane/consumption/cpemon-api-infra-outputs-example.yaml` |
| ADR and concepts | `ADR/cloud-platform-upgrade-crossplane-developer-self-service.md`, `docs/knowledge/crossplane-concepts.md` |

## Offline Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-story.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-final-checklist.ps1
go test ./...
git diff --check
```

Offline validation proves repository completeness and consistency. It does not
prove live cloud reconciliation.

## Live Validation Boundary

Live validation remains future work until these prerequisites exist:

* EKS cluster is reachable
* Argo CD is installed and authenticated
* Crossplane controller is healthy
* AWS providers and functions are healthy
* EKS OIDC provider and IRSA trust policy are configured
* AWS IAM role ARN is real, least-privilege, and trusted by the provider service account
* Kyverno is installed for admission validation

Live proof should include:

```powershell
argocd app sync crossplane-dev
argocd app sync crossplane-providers-dev
argocd app sync crossplane-platform-apis-dev
argocd app sync crossplane-claims-dev
kubectl get providers.pkg.crossplane.io
kubectl get xcpemonbuckets.platform.cpemon.io -n cpemon
kubectl get xcpemondynamotables.platform.cpemon.io -n cpemon
kubectl get xcpemonecrrepositories.platform.cpemon.io -n cpemon
kubectl describe clusterpolicy cpemon-crossplane-request-guardrails
```

## Final Interview Summary

```text
I introduced Crossplane as a developer self-service platform API without
replacing Terraform. Terraform still owns the EKS foundation. Crossplane exposes
approved app-level resources through XRDs and Compositions. Argo CD reconciles
providers, APIs, and requests. Kyverno enforces governance. IRSA avoids static
AWS keys. Offline validation proves the repository contract, and live validation
is explicitly separated for EKS/AWS reconciliation.
```
