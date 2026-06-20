# Incident Drill - EKS Nodes Not Joining Cluster

## Scope

This is the planned incident drill for `CCPU-43`.

The live drill cannot be executed yet because the EKS cluster and managed node group have not been applied. This runbook documents how to investigate the incident after the cluster exists.

## Symptom

Common symptoms:

```powershell
kubectl get nodes
```

returns:

- no resources
- NotReady nodes
- Unauthorized
- connection refused or timeout

Or AWS shows:

```text
NodeCreationFailure
CREATE_FAILED
DEGRADED
```

for the managed node group.

## First Split: Is This Access Or Node Join?

Run:

```powershell
kubectl get namespaces
kubectl get nodes -o wide
```

Interpretation:

- `kubectl get namespaces` fails with Unauthorized: cluster access problem.
- `kubectl get namespaces` works but nodes are missing: node group join problem.
- both commands cannot reach API server: kubeconfig, endpoint, security group, or cluster status problem.

## Check AWS Identity

```powershell
aws sts get-caller-identity --profile cpemon-terraform
```

Expected role family:

```text
AWSReservedSSO_CPEmonTerraformBootstrap
```

If the role differs, kubeconfig may authenticate with a principal that has no EKS access entry.

## Check Cluster Status

```powershell
aws eks describe-cluster `
  --region eu-north-1 `
  --name cpemon-dev `
  --profile cpemon-terraform `
  --query "cluster.{name:name,status:status,endpoint:endpoint,version:version,resourcesVpcConfig:resourcesVpcConfig}" `
  --output json
```

Expected:

```text
status = ACTIVE
endpointPublicAccess = true
```

If cluster is not ACTIVE, do not debug nodes first.

## Check Access Entry

```powershell
aws eks list-access-entries `
  --region eu-north-1 `
  --cluster-name cpemon-dev `
  --profile cpemon-terraform
```

Then:

```powershell
aws eks list-associated-access-policies `
  --region eu-north-1 `
  --cluster-name cpemon-dev `
  --principal-arn arn:aws:iam::701573843911:role/aws-reserved/sso.amazonaws.com/eu-north-1/AWSReservedSSO_CPEmonTerraformBootstrap_0241ccdc62503c71 `
  --profile cpemon-terraform
```

Expected policy:

```text
AmazonEKSClusterAdminPolicy
```

## Check Managed Node Group

```powershell
aws eks describe-nodegroup `
  --region eu-north-1 `
  --cluster-name cpemon-dev `
  --nodegroup-name cpemon-dev-ng-main `
  --profile cpemon-terraform `
  --output json
```

Look at:

- `status`
- `health.issues`
- `resources.autoScalingGroups`
- `subnets`
- `nodeRole`

If `health.issues` has codes, start there.

## Check Node IAM Role

Expected role:

```text
cpemon-dev-eks-node-role
```

Expected policies:

- `AmazonEKSWorkerNodePolicy`
- `AmazonEC2ContainerRegistryPullOnly`
- `AmazonEKS_CNI_Policy` temporarily

Common failure:

```text
NodeCreationFailure
```

can happen when the node role lacks required policies or cannot be passed/used by EKS.

## Check Subnets

The node group should use private subnets:

```text
10.40.10.0/24
10.40.11.0/24
10.40.12.0/24
```

Required subnet discovery tag:

```text
kubernetes.io/cluster/cpemon-dev = shared
```

For internal load balancers:

```text
kubernetes.io/role/internal-elb = 1
```

Commands:

```powershell
aws ec2 describe-subnets `
  --region eu-north-1 `
  --profile cpemon-terraform `
  --filters "Name=tag:kubernetes.io/cluster/cpemon-dev,Values=shared" `
  --query "Subnets[].{id:SubnetId,az:AvailabilityZone,cidr:CidrBlock,tags:Tags}" `
  --output json
```

## Check Network Path For Node Bootstrap

Worker nodes need to reach EKS and AWS service endpoints during bootstrap.

For private subnets, common production options are:

- NAT gateway route for outbound internet access.
- VPC endpoints for required AWS services.

Current Terraform foundation has subnets but does not yet define NAT, route tables, internet gateway, or VPC endpoints. If we apply the current graph as-is, node bootstrap may fail because private nodes may not have a working outbound path.

That is a major planned follow-up before real apply.

## Check Security Groups

EKS creates a cluster security group. Managed node groups also participate in security group rules.

Check:

```powershell
aws eks describe-cluster `
  --region eu-north-1 `
  --name cpemon-dev `
  --profile cpemon-terraform `
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" `
  --output text
```

Then:

```powershell
aws ec2 describe-security-groups `
  --region eu-north-1 `
  --profile cpemon-terraform `
  --group-ids <cluster-security-group-id>
```

Look for restrictive rules that block node-to-control-plane communication.

## Check EC2 Capacity And Quota

Current node instance type:

```text
t3.small
```

Possible failures:

- insufficient regional capacity
- EC2 quota too low
- unsupported instance type in selected AZ

Check node group health first. If capacity is the issue, change instance types or capacity type.

## Check Kubernetes Side

If nodes appear but are NotReady:

```powershell
kubectl describe node <node-name>
kubectl -n kube-system get pods -o wide
kubectl -n kube-system get daemonset aws-node
kubectl -n kube-system get pods -l k8s-app=aws-node -o wide
```

Common areas:

- VPC CNI not running.
- CoreDNS pending because no Ready nodes.
- kube-proxy issues.
- node taints or bootstrap problem.

## Current Project-Specific Warning

The current foundation intentionally stopped before apply.

Do not interpret this as a failed cluster:

```text
No cluster found for name: cpemon-dev
```

That is expected until Terraform apply creates the EKS cluster.

## Triage Decision Tree

1. Does `aws eks describe-cluster` find `cpemon-dev`?
2. Is cluster status `ACTIVE`?
3. Does `aws sts get-caller-identity` show the expected SSO role?
4. Does `kubectl get namespaces` work?
5. Does `aws eks describe-nodegroup` show `ACTIVE`?
6. Are node group health issues present?
7. Does the node role have required policies?
8. Do private subnets have a valid outbound bootstrap path?
9. Are EC2 capacity/quota errors present?
10. Are `aws-node`, kube-proxy, and CoreDNS healthy?

## Incident Summary Template

Use this format after a real drill:

```text
Incident:
EKS nodes not joining cpemon-dev.

Impact:
Pods cannot schedule because no Ready worker nodes exist.

Detection:
kubectl get nodes returned <result>.
aws eks describe-nodegroup showed <status/health issue>.

Root cause:
<subnet routing / IAM role / access entry / quota / CNI / other>

Fix:
<change made>

Validation:
kubectl get nodes -o wide shows Ready nodes.
kubectl get namespaces succeeds.

Prevention:
<Terraform validation, docs, monitoring, or permission update>
```
