# CPEmon Cloud Platform Upgrade Roadmap

## Step 1 - EKS GitOps Kafka Platform Upgrade

Goal: move from a YAML-first Kubernetes MVP to an EKS-based GitOps platform baseline.

Step 1 focuses on:

- AWS EKS as the managed Kubernetes target.
- Terraform for infrastructure as code.
- ECR and GitHub OIDC for image publishing and short-lived CI access to AWS.
- Federated human access to AWS console/CLI through AWS IAM Identity Center or an enterprise IdP.
- Helm charts for application and platform packaging.
- Argo CD for GitOps reconciliation.
- Kafka as the durable event buffer.
- Argo Rollouts with Prometheus analysis.
- External Secrets Operator for runtime secrets.
- Trivy, Kyverno, kubeconform, kube-linter, pre-commit hooks, and Terraform plan quality gates.
- OpenCost cost visibility.
- Renovate dependency automation.
- ADRs, developer golden path, and incident drill documentation.

Success means a reviewer can explain why the platform moved from the MVP model to the Step 1 model, how changes flow from pull request to cluster, and which controls protect the platform.

## Step 2 - Focused Platform Enhancements

Goal: add a small number of platform enhancements on top of the Step 1 foundation.

Completed Step 2 enhancements:

- Crossplane for platform resource provisioning.
- k8sGPT-assisted operational insight.

Final packaging:

- Developer golden path.
- Final architecture diagrams.
- Evidence matrix.
- Final demo script.
- Interview pack.
- Service catalog metadata.

Step 2 is intentionally small. The goal is to avoid turning the MVP upgrade into a full internal developer platform before the EKS, GitOps, CI, security, and cost visibility baseline is proven.

## Future Roadmap

- Backstage full portal.
- KEDA and Karpenter after HPA and static node group baselines.
- SBOM, Cosign, and SLSA.
- K8sGPT alert enrichment after privacy, quality, and cost controls are proven.
- Production-grade live EKS validation and disaster recovery drills.
