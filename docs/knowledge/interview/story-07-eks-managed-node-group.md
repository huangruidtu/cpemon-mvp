# Story 7: EKS Provisioning - Managed Node Group

## Q1: What problem does an EKS managed node group solve?

An EKS cluster control plane cannot run application pods by itself. A managed node group creates EC2 worker nodes, joins them to the cluster, and lets AWS manage health replacement and Auto Scaling Group integration.

In this project, the node group is the first compute layer where CPEmon pods can eventually run.

## Q2: Why does the node group need a separate IAM role?

The cluster role is used by the EKS service control plane. The node role is used by EC2 worker nodes through an instance profile.

The node role needs permissions for kubelet and node-level AWS calls, like describing EC2 resources and pulling images from ECR. AWS explicitly says the node role should not be the same role used to create clusters.

## Q3: Why is the node role trust policy `ec2.amazonaws.com` instead of `eks.amazonaws.com`?

Because the role is assumed by EC2 instances that become Kubernetes worker nodes. EKS creates and manages the node group, but the running machines are EC2 instances.

The Terraform trust policy says:

```hcl
principals {
  type        = "Service"
  identifiers = ["ec2.amazonaws.com"]
}
```

## Q4: Which AWS managed policies are attached to the node role?

The module attaches:

- `AmazonEKSWorkerNodePolicy`
- `AmazonEC2ContainerRegistryPullOnly`
- `AmazonEKS_CNI_Policy`

The first two are core node permissions. The CNI policy is temporary for this dev phase. AWS recommends moving VPC CNI permissions to a separate service-account role with IRSA or EKS Pod Identity.

## Q5: Why use private subnets for worker nodes?

Worker nodes should not be directly exposed to the internet. Public traffic should enter through controlled entry points such as load balancers or ingress controllers, while nodes stay in private subnets.

In Terraform, the node group receives:

```hcl
subnet_ids = module.vpc_subnets.private_subnet_ids
```

## Q6: What do `desired_size`, `min_size`, and `max_size` mean?

They control the node group's scaling boundary.

`desired_size` is the target number of nodes Terraform asks AWS to create initially. `min_size` is the lower bound. `max_size` is the upper bound.

For dev, the project uses:

```text
desired = 1
min = 1
max = 2
```

That gives one working node while keeping the cost boundary small.

## Q7: Why did we choose `ON_DEMAND` instead of `SPOT`?

`ON_DEMAND` is more stable for a first EKS learning environment and interview demo. `SPOT` is cheaper but can be interrupted, which adds operational complexity.

For non-production workloads, a later task could introduce a second SPOT node group.

## Q8: Why did we not apply this immediately?

Applying would create real paid resources: VPC resources, EKS control plane, IAM roles, and EC2 worker nodes.

For this story, the acceptance standard is module completeness and successful `terraform plan`. Actual apply is better done once cluster access, add-ons, kubeconfig validation, and cleanup steps are ready.

## Q9: What would you say in an interview about this design?

I separated the EKS control plane and worker node group into different Terraform modules. The managed node group module creates a dedicated EC2 node role, attaches the required EKS worker and ECR pull policies, places nodes in private subnets, and uses a conservative dev scaling config. I deliberately kept apply deferred because EKS and EC2 have ongoing cost, and I documented the future hardening step of moving VPC CNI permissions to IRSA or EKS Pod Identity.

## Q10: What permission issue might happen during apply?

The Terraform execution role may need permission to create the node role, attach the required managed policies, pass the node role to EKS, and call `eks:CreateNodegroup`.

The important learning point is that Terraform permissions are not just "admin or nothing". A production platform team usually grows a narrow permission boundary around the exact resources Terraform is allowed to manage.
