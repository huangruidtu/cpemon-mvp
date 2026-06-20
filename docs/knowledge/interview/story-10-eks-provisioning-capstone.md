# Story 10: EKS Provisioning Capstone and Incident Drill

## Q1: What did you build in the EKS provisioning foundation?

I built a Terraform-based EKS foundation for CPEmon dev. It includes VPC, public and private subnets, EKS cluster definition, managed node group, explicit cluster access entries, and a kubeconfig validation runbook.

I deliberately kept it plan-only because creating EKS and EC2 resources creates real cost.

## Q2: What is the high-level dependency chain?

The chain is:

```text
remote state -> VPC -> subnets -> EKS cluster role -> EKS cluster -> node role -> managed node group -> access entry -> kubeconfig -> kubectl validation
```

This is important because Terraform builds the graph from references between modules.

## Q3: Why did you not apply the EKS resources yet?

EKS control plane and worker nodes cost money. Also, the current network foundation does not yet include NAT gateways, route tables, or VPC endpoints, which private worker nodes may need for bootstrap.

So I treated the story as validated infrastructure code plus operator documentation, and deferred apply until we have a cost window and cleanup plan.

## Q4: What does the VPC provide for EKS?

The VPC is the network boundary. EKS worker nodes, load balancers, pod networking, and security groups all depend on VPC design.

In this project, the dev VPC uses:

```text
10.40.0.0/16
```

## Q5: Why split public and private subnets?

Public subnets are prepared for internet-facing load balancers. Private subnets are prepared for worker nodes and internal services.

This follows the common cloud pattern where nodes are not directly public, but traffic enters through controlled load balancers or ingress.

## Q6: What do the Kubernetes subnet tags do?

They allow Kubernetes/AWS controllers to discover suitable subnets.

Examples:

```text
kubernetes.io/cluster/cpemon-dev = shared
kubernetes.io/role/elb = 1
kubernetes.io/role/internal-elb = 1
```

## Q7: What is the EKS cluster role?

The cluster role is assumed by `eks.amazonaws.com`. It gives the EKS control plane permission to manage AWS resources it needs for cluster operation.

It is separate from the node role.

## Q8: What is the node role?

The node role is assumed by `ec2.amazonaws.com`. It is attached to worker nodes so kubelet and node components can interact with AWS services.

Current policies:

- `AmazonEKSWorkerNodePolicy`
- `AmazonEC2ContainerRegistryPullOnly`
- temporary `AmazonEKS_CNI_Policy`

## Q9: Why is the CNI policy temporary on the node role?

Because we have not yet created IRSA or EKS Pod Identity for the `aws-node` service account.

Long term, the VPC CNI should get its own service-account-level IAM role so the worker node role is not overly broad.

## Q10: What is the difference between IAM permission and EKS access permission?

IAM permission controls AWS API calls.

EKS access permission controls what an authenticated IAM principal can do inside Kubernetes.

For example, `eks:DescribeCluster` can let a user fetch cluster metadata, but it does not automatically allow `kubectl get pods`.

## Q11: Why use access entries instead of aws-auth?

Access entries are managed through the EKS API and can be defined in Terraform. That is easier to audit and recover than relying on manual edits to the `aws-auth` ConfigMap.

This project uses:

```text
authentication_mode = API
```

## Q12: Why disable bootstrap cluster creator admin?

Because implicit access is harder to audit, and creating an explicit access entry for the same principal can cause duplicate-entry errors.

For a new cluster, it is cleaner to set:

```text
bootstrap_cluster_creator_admin_permissions = false
```

and manage access explicitly.

## Q13: What is kubeconfig?

Kubeconfig is local client configuration for `kubectl`. It stores cluster endpoint, certificate authority data, users, and contexts.

For EKS, it is generated with:

```powershell
aws eks update-kubeconfig --region eu-north-1 --name cpemon-dev --profile cpemon-terraform --alias cpemon-dev
```

## Q14: Why can kubeconfig exist but kubectl still be Unauthorized?

Kubeconfig only configures how to authenticate and reach the cluster. The IAM principal still needs authorization through EKS access entries or Kubernetes RBAC.

That is why debugging starts with:

```powershell
aws sts get-caller-identity --profile cpemon-terraform
```

## Q15: What does `kubectl get nodes` prove?

It proves that worker nodes have registered with the Kubernetes control plane.

If `kubectl get namespaces` works but `kubectl get nodes` shows no nodes, access may be fine while node bootstrap is failing.

## Q16: What are common reasons EKS nodes do not join?

Common reasons:

- node IAM role missing required policies
- private subnet has no outbound path
- VPC CNI problems
- security group restrictions
- cluster endpoint access mismatch
- EC2 quota or capacity issue
- node group health issue
- wrong AWS identity or access entry

## Q17: What is the first command in a node-not-joining incident?

Start with AWS cluster status:

```powershell
aws eks describe-cluster --region eu-north-1 --name cpemon-dev --profile cpemon-terraform
```

If the cluster does not exist or is not ACTIVE, do not debug worker nodes yet.

## Q18: What command checks node group health?

```powershell
aws eks describe-nodegroup --region eu-north-1 --cluster-name cpemon-dev --nodegroup-name cpemon-dev-ng-main --profile cpemon-terraform
```

Look at `status` and `health.issues`.

## Q19: Why might private nodes fail to bootstrap in the current foundation?

The current foundation creates private subnets but does not yet create NAT gateways, route tables, internet gateway, or VPC endpoints.

Private nodes need a way to reach EKS and AWS services during bootstrap. Without that path, node group creation may fail even if IAM is correct.

## Q20: How would you summarize this project to an interviewer?

I took a Kubernetes MVP and started migrating its platform foundation toward AWS EKS using Terraform. I did not jump straight into a one-shot cluster apply. I built the platform in layers: state, registry, CI identity, network, cluster, node group, access, and operator validation. For each layer I documented the design choices, permissions, validation commands, and failure modes. That shows both infrastructure-as-code implementation skill and operational thinking.
