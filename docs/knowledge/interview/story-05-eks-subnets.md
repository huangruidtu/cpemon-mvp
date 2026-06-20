# Story 5: EKS Provisioning - Public and Private Subnets

## Short Version

I created public and private subnet pairs across three Availability Zones for the future EKS cluster. The public subnets are prepared for internet-facing load balancers, and the private subnets are prepared for worker nodes and internal load balancers.

## Interview Q&A

### Q: Why does EKS need subnets?

EKS worker nodes, load balancers, and platform add-ons need actual network locations inside the VPC. Subnets provide those locations and place resources into specific Availability Zones.

### Q: What is the difference between a public subnet and a private subnet?

A public subnet is intended for resources that can be reached from the internet through an internet gateway and route table.

A private subnet is intended for resources without direct public internet exposure.

In this project, public subnets are for internet-facing load balancers, while private subnets are for worker nodes and internal load balancers.

### Q: Does map_public_ip_on_launch make a subnet public by itself?

No. It only controls whether instances launched into the subnet automatically receive public IPs.

A subnet also needs a route to an internet gateway to actually behave as a public subnet. That routing is intentionally handled in a later task.

### Q: Why create subnets across three Availability Zones?

Multiple AZs improve failure isolation and prepare the platform for a production-style EKS topology.

If one AZ has an issue, the cluster can still have resources in other AZs.

### Q: What EKS tags did you add to subnets?

All subnets get:

```text
kubernetes.io/cluster/cpemon-dev = shared
```

Public subnets get:

```text
kubernetes.io/role/elb = 1
```

Private subnets get:

```text
kubernetes.io/role/internal-elb = 1
```

These tags help AWS Kubernetes integrations discover which subnets to use for load balancers.

### Q: Why use shared instead of owned in the cluster tag?

`shared` means the subnet is associated with the cluster but not exclusively owned by it. That is a conservative choice for Terraform-managed shared infrastructure.

`owned` is more appropriate when the subnet lifecycle is tightly owned by one cluster.

### Q: What did the Terraform plan show?

The plan showed:

```text
Plan: 7 to add, 0 to change, 0 to destroy.
```

That means Terraform would create one VPC and six subnets: three public and three private.

### Q: Why was the VPC still in the subnet plan?

Because the VPC was planned in the previous task but not applied yet.

Terraform understands the dependency graph: it will create `module.vpc.aws_vpc.this` first, then create the subnets using the VPC ID.

### Q: What permission issue came up?

The first version used `data "aws_availability_zones"` to ask AWS for available AZs. The plan failed because the role lacked:

```text
ec2:DescribeAvailabilityZones
```

The fix was to use explicit dev AZ inputs for now and document the missing permission. The learning point is that even Terraform plan can need AWS read permissions.

### Q: How would you explain this in one minute?

After creating the VPC, I added a subnet module that creates public and private subnet pairs across three Availability Zones. The public subnets are tagged for external load balancers, and the private subnets are tagged for internal load balancers and future worker nodes. I kept route tables, internet gateway, and NAT out of this step so the network design stays reviewable layer by layer.
