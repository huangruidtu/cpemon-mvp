# Story 4: EKS Provisioning - VPC Module

## Short Version

I started the EKS migration by creating a Terraform VPC module. The VPC is the AWS network boundary where the future EKS cluster, subnets, worker nodes, load balancers, and platform add-ons will live.

## Interview Q&A

### Q: Why did you start EKS provisioning with a VPC?

EKS depends on AWS networking. Even though AWS manages the Kubernetes control plane, the cluster still needs VPC networking for worker nodes, pod networking, load balancers, and access to AWS services.

Starting with the VPC creates the network foundation before adding subnets, route tables, NAT, or the EKS cluster itself.

### Q: What is a VPC in simple terms?

A VPC is a private network inside an AWS region. It defines the IP address space and network boundary for cloud resources.

For CPEmon, the VPC is where the dev EKS platform will be built.

### Q: Why did you create a Terraform module instead of putting aws_vpc directly in main.tf?

I used a module to keep the infrastructure organized and reusable.

The environment root decides what the dev environment uses. The module contains the reusable VPC implementation. That separation becomes more valuable as the platform grows because networking, EKS, IAM, and later add-ons can each have clear boundaries.

### Q: What does the VPC module create right now?

It creates one AWS VPC with:

- A configurable CIDR block.
- DNS hostnames enabled.
- DNS support enabled.
- A consistent Name tag.
- Outputs such as VPC ID and CIDR block.

### Q: Why enable DNS hostnames and DNS support?

EKS nodes and workloads often need normal AWS DNS behavior to reach AWS APIs, registries, package endpoints, and service discovery. Keeping DNS support enabled avoids a common class of networking problems.

### Q: What CIDR did you choose and why?

The dev example uses:

```text
10.40.0.0/16
```

That gives enough private IP space to split into multiple public and private subnets later. For a real company environment, I would not choose a CIDR casually. I would check the organization's network allocation plan to avoid overlap with existing VPCs, VPNs, office networks, or shared services.

### Q: What did you intentionally not include in this first VPC module task?

I did not create subnets, route tables, internet gateway, NAT gateway, EKS subnet tags, EKS cluster, or node groups in this step.

Those are separate tasks because each one adds new design decisions. Keeping the VPC step small makes the Terraform plan easier to review and teaches the foundation first.

### Q: How do later Terraform resources use this VPC?

The VPC module exports outputs such as:

```hcl
module.vpc.vpc_id
```

Later subnet resources can use that output:

```hcl
vpc_id = module.vpc.vpc_id
```

That creates an explicit Terraform dependency, so Terraform knows the VPC must exist before the subnets.

### Q: What should you look for in terraform plan for this step?

I would expect Terraform to add one VPC resource:

```text
module.vpc.aws_vpc.this
```

I would check that the CIDR is correct, DNS settings are enabled, and the tags identify the project and environment.

### Q: What are common mistakes in this step?

Common mistakes include choosing a bad or overlapping CIDR block, forgetting DNS settings, missing useful outputs, or mixing too many future resources into the first module.

### Q: How would you explain this in one minute?

The first step in moving CPEmon to EKS was creating the AWS network boundary with Terraform. I built a small VPC module that creates the dev VPC, enables DNS support, applies consistent tags, and exports the VPC ID for later subnet and EKS resources. I kept it intentionally small so that networking decisions can be reviewed step by step before adding subnets, NAT, EKS control plane, and managed node groups.

## Practice Prompt

Explain why an EKS cluster needs AWS VPC planning even though AWS manages the Kubernetes control plane.
