# EKS Foundation and GitOps Platform Path

## Ownership Model

```text
Terraform = foundation
Argo CD = cluster reconciliation
Helm = packaging
Kubernetes manifests = platform and application contracts
```

Terraform owns high-blast-radius infrastructure:

* VPC
* subnets
* EKS cluster
* managed node groups
* IAM/OIDC
* ECR-related foundation

Argo CD owns in-cluster desired state:

* CPEmon application chart
* Kafka
* monitoring
* External Secrets Operator
* Kyverno
* OpenCost
* Argo Rollouts
* Crossplane
* K8sGPT

## Platform Add-On Order

Recommended order:

1. namespaces
2. Argo CD
3. Argo CD project
4. External Secrets Operator
5. Kafka
6. monitoring
7. CPEmon app
8. Argo Rollouts
9. Kyverno and policies
10. OpenCost
11. Crossplane and providers
12. K8sGPT

## Key Directories

```text
infra/terraform/
k8s/base/
k8s/gitops/dev/applications/
k8s/addons/
deploy/helm/cpemon/
ops/runbooks/
ADR/
```

## Interview Framing

The important decision is separation of ownership:

```text
Terraform builds the platform foundation. Argo CD continuously reconciles
application and platform add-ons inside the cluster. Helm gives reusable
application packaging. Crossplane is introduced later for selected
developer-facing resources, not to replace Terraform.
```
