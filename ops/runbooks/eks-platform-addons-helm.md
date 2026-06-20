# EKS Platform Add-ons Helm Runbook

## Purpose

Use this runbook to install and validate the first EKS platform add-ons with Helm.

Covered tasks:

- `CCPU-44`: metrics-server
- `CCPU-45`: AWS Load Balancer Controller

## Current Boundary

The EKS cluster has not been applied yet. This runbook prepares the commands and expected checks, but the Helm installs can only run after:

- the EKS control plane exists
- the managed node group is Ready
- kubeconfig points to the dev cluster
- `helm` and `kubectl` are installed locally
- AWS Load Balancer Controller IAM prerequisites exist

## Why Helm

We are intentionally not using raw `kubectl apply` install URLs for these add-ons.

Helm gives us:

- chart versioning
- repeatable values files
- upgrade/uninstall workflow
- one place to record environment-specific settings
- a cleaner interview story for platform add-on management

## Add Helm Repositories

```powershell
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

Makefile shortcut:

```powershell
make helm-repos
```

## Install metrics-server

Values file:

```text
k8s/addons/metrics-server/values.yaml
```

Install:

```powershell
helm upgrade --install metrics-server metrics-server/metrics-server `
  --namespace kube-system `
  --version 3.13.1 `
  --values k8s/addons/metrics-server/values.yaml
```

Makefile shortcut:

```powershell
make metrics-server
```

Validate:

```powershell
kubectl get deployment -n kube-system metrics-server
kubectl top nodes
kubectl top pods -A
```

Makefile shortcut:

```powershell
make metrics-server-check
```

## Install AWS Load Balancer Controller

Values file:

```text
k8s/addons/aws-load-balancer-controller/values.yaml
```

The controller needs AWS permissions because it creates and manages AWS load balancers. The normal EKS path is to give the Kubernetes service account an IAM role through IRSA or EKS Pod Identity.

For this project, use IRSA-style service account annotation when the IAM role is ready:

```text
eks.amazonaws.com/role-arn = arn:aws:iam::<account-id>:role/<aws-lbc-role-name>
```

Install:

```powershell
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
  --namespace kube-system `
  --version 1.14.0 `
  --values k8s/addons/aws-load-balancer-controller/values.yaml `
  --set clusterName=cpemon-dev `
  --set region=eu-north-1 `
  --set vpcId=<vpc-id> `
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<aws-lbc-role-arn>
```

Makefile shortcut:

```powershell
make aws-lbc EKS_VPC_ID=<vpc-id> AWS_LBC_ROLE_ARN=<aws-lbc-role-arn>
```

Validate:

```powershell
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=80
```

Makefile shortcut:

```powershell
make aws-lbc-check
```

## Troubleshooting

If Helm cannot reach the cluster:

```powershell
kubectl config current-context
kubectl cluster-info
```

If metrics-server is running but `kubectl top nodes` fails:

- confirm nodes are Ready
- confirm metrics-server pod logs
- confirm RBAC allows reading metrics
- confirm node security groups allow kubelet metrics traffic

If AWS Load Balancer Controller starts but cannot create load balancers:

- confirm the service account has the IAM role annotation
- confirm the IAM role trust policy matches the cluster OIDC provider
- confirm the IAM policy includes required ELBv2/EC2/IAM describe/tag actions
- confirm public/private subnet tags exist for EKS load balancer discovery
- check controller logs before changing Kubernetes Ingress manifests
