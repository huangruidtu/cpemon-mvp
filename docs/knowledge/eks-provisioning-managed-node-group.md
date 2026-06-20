# EKS Provisioning with Terraform - Managed Node Group

## Why This Subtask Exists

`CCPU-40` adds the first EKS managed node group.

The EKS cluster from the previous task is only the Kubernetes control plane. It can accept API requests, but it cannot run CPEmon pods until worker nodes join the cluster.

A managed node group lets AWS create and operate a group of EC2 worker nodes for EKS. AWS handles the backing Auto Scaling Group integration, health replacement, and Kubernetes node registration flow. Terraform defines the desired shape.

## What Gets Created

The implementation lives in:

```text
infra/terraform/modules/eks_managed_node_group
```

The dev environment calls it from:

```text
infra/terraform/envs/dev/main.tf
```

The module creates:

- An IAM trust policy for EC2 worker nodes.
- An IAM role for the worker nodes.
- Required AWS managed policy attachments for EKS node operation.
- One EKS managed node group in the private subnets.

## Why Worker Nodes Need Their Own IAM Role

AWS documentation says EKS nodes receive AWS permissions through an IAM instance profile and associated policies. The node role is different from the cluster role.

That distinction matters:

- Cluster role: used by the EKS control plane service.
- Node role: used by EC2 instances running kubelet and pods.

The node trust policy uses:

```hcl
principals {
  type        = "Service"
  identifiers = ["ec2.amazonaws.com"]
}
```

This means EC2 instances are allowed to assume the role. It is not `eks.amazonaws.com` because the role is attached to the worker machines.

## Required Node Policies

The module attaches:

```hcl
arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly
```

`AmazonEKSWorkerNodePolicy` gives kubelet the AWS permissions it needs to describe cluster and EC2 information.

`AmazonEC2ContainerRegistryPullOnly` lets worker nodes pull container images from ECR. That matters because EKS networking add-ons and CPEmon images can come from ECR.

The module currently also attaches:

```hcl
arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
```

This is intentionally controlled by:

```hcl
attach_vpc_cni_policy_to_node_role = true
```

AWS recommends moving VPC CNI permissions to a separate IAM role for the `aws-node` Kubernetes service account, using IRSA or EKS Pod Identity. We have not built that service-account IAM boundary yet, so the dev node role temporarily carries the CNI policy. A later hardening task should move it off the node role.

## Managed Node Group Resource

The core Terraform resource is:

```hcl
resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
}
```

Line by line:

- `cluster_name` tells AWS which EKS cluster the nodes should join.
- `node_group_name` gives the node group a stable AWS name.
- `node_role_arn` gives EC2 nodes the permissions they need.
- `subnet_ids` chooses where worker EC2 instances run.

For CPEmon dev, the subnet IDs come from:

```hcl
module.vpc_subnets.private_subnet_ids
```

That means worker nodes run in private subnets. They should not be directly internet-facing.

## Capacity Settings

The dev environment uses:

```hcl
eks_node_capacity_type   = "ON_DEMAND"
eks_node_instance_types  = ["t3.small"]
eks_node_disk_size       = 20
eks_node_desired_size    = 1
eks_node_min_size        = 1
eks_node_max_size        = 2
eks_node_max_unavailable = 1
```

Meaning:

- `ON_DEMAND`: stable capacity for learning and demos. Later we can evaluate `SPOT` for cheaper non-production workloads.
- `t3.small`: low-cost dev instance type. It is intentionally small and may not be enough for heavier add-ons.
- `disk_size = 20`: 20 GiB root EBS volume per node.
- `desired_size = 1`: start with one worker node.
- `min_size = 1`: keep at least one worker node.
- `max_size = 2`: allow small scale-out without opening cost too much.
- `max_unavailable = 1`: update one node at a time.

## Why Depends On Policy Attachments

The node group depends on the node role policy attachments:

```hcl
depends_on = [
  aws_iam_role_policy_attachment.worker_node,
  aws_iam_role_policy_attachment.ecr_pull_only,
  aws_iam_role_policy_attachment.cni,
]
```

This prevents Terraform from asking EKS to create nodes before the node role has usable permissions. It also helps deletion ordering, so EKS can still clean up EC2 resources before IAM permissions are removed.

## Apply Is Still Deferred

This task is still plan-only.

Reasons:

- Applying now would create the VPC, subnets, EKS control plane, IAM roles, and EC2 worker nodes.
- EKS control plane and EC2 nodes create real AWS cost.
- The platform still needs access validation, add-ons, kubeconfig workflow, and a clear cleanup path.

Acceptance for this task is:

- Terraform module exists.
- Dev environment wires the module correctly.
- `terraform fmt` passes.
- `terraform validate` passes.
- Backend-backed `terraform plan` succeeds.

## Validation Result

The backend-backed plan succeeded:

```text
Plan: 15 to add, 0 to change, 0 to destroy.
```

The node-group-specific planned resources are:

```text
module.eks_managed_node_group.aws_iam_role.node
module.eks_managed_node_group.aws_iam_role_policy_attachment.worker_node
module.eks_managed_node_group.aws_iam_role_policy_attachment.ecr_pull_only
module.eks_managed_node_group.aws_iam_role_policy_attachment.cni[0]
module.eks_managed_node_group.aws_eks_node_group.this
```

The remaining planned resources are the VPC, six subnets, cluster IAM role, cluster policy attachment, and EKS cluster from the earlier EKS provisioning subtasks.

## Apply Permission Requirements

When we later apply, the `CPEmonTerraformBootstrap` permission set will need node-group-specific permissions.

Node role management:

```json
{
  "Sid": "ManageCpemonDevEksNodeRole",
  "Effect": "Allow",
  "Action": [
    "iam:CreateRole",
    "iam:TagRole",
    "iam:GetRole",
    "iam:ListRolePolicies",
    "iam:GetRolePolicy",
    "iam:ListAttachedRolePolicies",
    "iam:ListInstanceProfilesForRole",
    "iam:AttachRolePolicy",
    "iam:DetachRolePolicy",
    "iam:DeleteRole"
  ],
  "Resource": "arn:aws:iam::701573843911:role/cpemon-dev-eks-node-role"
}
```

Pass the node role to EKS:

```json
{
  "Sid": "PassCpemonDevEksNodeRoleToEks",
  "Effect": "Allow",
  "Action": [
    "iam:PassRole"
  ],
  "Resource": "arn:aws:iam::701573843911:role/cpemon-dev-eks-node-role",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "eks.amazonaws.com"
    }
  }
}
```

Manage the dev node group:

```json
{
  "Sid": "ManageCpemonDevEksManagedNodeGroup",
  "Effect": "Allow",
  "Action": [
    "eks:CreateNodegroup",
    "eks:DescribeNodegroup",
    "eks:DeleteNodegroup",
    "eks:UpdateNodegroupConfig",
    "eks:UpdateNodegroupVersion",
    "eks:TagResource",
    "eks:UntagResource",
    "eks:ListTagsForResource"
  ],
  "Resource": "arn:aws:eks:eu-north-1:701573843911:nodegroup/cpemon-dev/cpemon-dev-ng-main/*"
}
```

Attach only the AWS managed policies used by the node role:

```json
{
  "Sid": "AttachOnlyCpemonEksNodeManagedPolicies",
  "Effect": "Allow",
  "Action": [
    "iam:AttachRolePolicy"
  ],
  "Resource": "arn:aws:iam::701573843911:role/cpemon-dev-eks-node-role",
  "Condition": {
    "ArnEquals": {
      "iam:PolicyARN": [
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      ]
    }
  }
}
```

Keep the permission set narrow and expand only when a real Terraform error proves another action is required.

## Interview Explanation

After creating the EKS control plane, I added a managed node group module so the cluster can eventually run workloads. The node group creates a separate EC2 node IAM role, attaches the required EKS and ECR pull policies, places nodes in private subnets, and starts with a very small dev scaling config. I kept the task plan-only because applying it would create paid EKS and EC2 resources. I also documented that the VPC CNI policy is temporarily on the node role and should later move to an IRSA or EKS Pod Identity role for the `aws-node` service account.

## Sources

- AWS EKS node IAM role: <https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html>
- Terraform `aws_eks_node_group`: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group>
