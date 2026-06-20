# Story 8: EKS Provisioning - Cluster Access

## Q1: Why is cluster access a separate task from cluster creation?

Creating an EKS cluster creates the Kubernetes API endpoint, but it does not automatically define a clean long-term access model for humans and automation.

Cluster access answers: which IAM principals can authenticate to Kubernetes, and what Kubernetes permissions do they receive?

## Q2: Why use EKS access entries instead of the aws-auth ConfigMap?

EKS access entries let us manage access through the EKS API and Terraform. That is cleaner than manually editing `aws-auth` inside Kubernetes because access can be managed before depending on in-cluster Kubernetes permissions.

It also keeps the access model visible in infrastructure code.

## Q3: What is the difference between IAM permissions and EKS access policies?

IAM permissions decide what an AWS principal can do against AWS APIs.

EKS access policies decide what that authenticated principal can do inside Kubernetes.

For example, an IAM role might be allowed to call `eks:DescribeCluster`, but that does not automatically mean it can list pods. The role also needs EKS/Kubernetes authorization through an access entry and policy association.

## Q4: Why did you use an IAM role ARN instead of the STS assumed-role ARN?

`aws sts get-caller-identity` returns the temporary session ARN:

```text
arn:aws:sts::701573843911:assumed-role/AWSReservedSSO_CPEmonTerraformBootstrap_0241ccdc62503c71/cpemon-terraform
```

EKS access entries should point to the stable IAM principal:

```text
arn:aws:iam::701573843911:role/aws-reserved/sso.amazonaws.com/eu-north-1/AWSReservedSSO_CPEmonTerraformBootstrap_0241ccdc62503c71
```

The STS ARN is the session. The IAM role ARN is the identity boundary.

## Q5: Why disable bootstrap cluster creator admin permissions?

If bootstrap admin is enabled, EKS can implicitly grant admin access to the principal that creates the cluster. If Terraform then tries to create an explicit access entry for the same principal, apply can fail with a duplicate access-entry error.

Because this cluster has not been applied yet, we can choose the cleaner Day 0 model:

```text
bootstrap_cluster_creator_admin_permissions = false
explicit EKS access entry = true
```

That makes access auditable in Terraform.

## Q6: Which policy did you associate for the dev admin role?

For the first dev admin path, the module associates:

```text
AmazonEKSClusterAdminPolicy
```

with cluster scope.

That is intentionally broad for the platform admin role. Later roles should be narrower, such as namespace-scoped edit or view access.

## Q7: What command creates kubeconfig after apply?

```bash
aws eks update-kubeconfig \
  --region eu-north-1 \
  --name cpemon-dev \
  --profile cpemon-terraform \
  --alias cpemon-dev
```

This writes a kubeconfig context that uses AWS IAM authentication for EKS.

## Q8: How do you validate access?

Run:

```bash
aws sts get-caller-identity --profile cpemon-terraform
kubectl config current-context
kubectl get nodes
kubectl get namespaces
```

If `kubectl get namespaces` works, Kubernetes API access is working. If nodes are not Ready yet, that might be a node bootstrap issue rather than an access issue.

## Q9: What permission might Terraform need for this task?

Terraform needs EKS access-management permissions such as:

- `eks:CreateAccessEntry`
- `eks:DescribeAccessEntry`
- `eks:AssociateAccessPolicy`
- `eks:DisassociateAccessPolicy`
- `eks:DeleteAccessEntry`
- `eks:ListAccessPolicies`

This is separate from the Kubernetes access that the created entry grants.

## Q10: How would you explain this in an interview?

I used EKS access entries as the cluster access model instead of relying on the legacy `aws-auth` ConfigMap. Terraform creates an access entry for the IAM Identity Center role used by the platform operator and associates the AWS-managed cluster-admin access policy. I disabled implicit cluster creator admin access before first apply to avoid hidden access and duplicate-entry conflicts. After apply, access is validated through `aws eks update-kubeconfig` and basic `kubectl` commands.
