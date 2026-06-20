# Story 6: EKS Provisioning - Cluster Module

## Short Version

I created a Terraform module for the EKS control plane. It creates the cluster IAM role, attaches the AWS managed cluster policy, and provisions the EKS cluster into the private subnets prepared earlier.

## Interview Q&A

### Q: What does the EKS cluster module create?

It creates:

- The EKS cluster IAM role.
- The trust policy that lets `eks.amazonaws.com` assume the role.
- The `AmazonEKSClusterPolicy` attachment.
- The EKS control plane.

### Q: Why does an EKS cluster need an IAM role?

EKS needs an IAM role so the managed Kubernetes control plane can interact with AWS resources on behalf of the cluster.

The trust policy allows the EKS service to assume the role, and the attached policy gives it the permissions required for cluster operations.

### Q: What is AmazonEKSClusterPolicy?

`AmazonEKSClusterPolicy` is an AWS managed policy used by the EKS cluster role. It gives Kubernetes/EKS the permissions needed to manage cluster-related AWS resources.

### Q: Why did you use private subnets for the cluster?

The private subnets are the intended internal network layer for EKS infrastructure. Worker nodes will also use private subnets later.

The public subnets are mainly prepared for internet-facing load balancers.

### Q: Why is the endpoint public in dev?

Public endpoint access makes early validation easier because `kubectl` can reach the Kubernetes API from the operator machine.

For a hardened environment, I would restrict public access CIDRs, enable private endpoint access, or use a VPN/bastion/private network path.

### Q: Why use authentication_mode = API?

EKS now supports access management through EKS access entries. Using API mode prepares the cluster for that model instead of depending only on the older `aws-auth` ConfigMap path.

### Q: What does bootstrap_cluster_creator_admin_permissions do?

It gives the principal that creates the cluster initial admin access through EKS access management.

This helps avoid immediately locking yourself out of a brand-new cluster. Later, access should be made explicit with access entries and policies.

### Q: What did the Terraform plan show?

The plan showed:

```text
Plan: 10 to add, 0 to change, 0 to destroy.
```

The EKS-specific resources are the cluster IAM role, policy attachment, and EKS cluster.

### Q: Why did you not apply the EKS cluster immediately?

An EKS control plane starts creating ongoing AWS cost after apply. At this stage, the cluster module was ready, but node groups, cluster access validation, and kubeconfig workflow were not complete yet.

So I treated this subtask as plan-validated infrastructure code and deferred apply until the cluster can be created together with worker capacity and validation steps.

### Q: Why are VPC and subnets still in the plan?

Because they have been planned but not applied yet.

Terraform sees the full dependency chain: create the VPC, then subnets, then the EKS cluster using those subnet IDs.

### Q: What is intentionally left for later?

Managed node groups, node IAM role, kubeconfig generation, kubectl validation, and explicit cluster access entries are left for later subtasks.

### Q: How would you explain this in one minute?

After preparing the VPC and subnets, I added an EKS cluster module for the managed Kubernetes control plane. The module creates the required IAM role, attaches `AmazonEKSClusterPolicy`, and provisions the cluster into the private subnet layer. I kept node groups and access entries separate so the control plane, worker capacity, and access model can each be reviewed independently.
