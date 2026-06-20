# EKS Echo External Access Runbook

## Purpose

Use this runbook to expose the platform echo service through AWS Load Balancer Controller and verify external HTTP access.

This runbook belongs to `CCPU-49`.

## Current Boundary

The EKS cluster has not been applied yet, and AWS Load Balancer Controller has not been installed into a live cluster yet. This runbook prepares the ALB Ingress manifest and validation path for the post-apply window.

## Files

```text
k8s/samples/echo/ing.yaml
```

Prerequisite files:

```text
k8s/samples/echo/deploy.yaml
k8s/samples/echo/svc.yaml
k8s/addons/aws-load-balancer-controller/values.yaml
```

## Request Path

```text
curl/browser
  -> AWS Application Load Balancer
  -> ALB listener on port 80
  -> target group
  -> EKS pod IP
  -> Kubernetes Service echo
  -> echo Pod
```

The Ingress uses:

```text
ingressClassName: alb
alb.ingress.kubernetes.io/scheme: internet-facing
alb.ingress.kubernetes.io/target-type: ip
```

`target-type: ip` is useful on EKS because the ALB target group can route directly to pod IPs.

## Apply

Make sure the echo Deployment and Service exist first:

```powershell
make echo
make echo-check
```

Then apply the Ingress:

```powershell
make echo-ingress
```

Direct command:

```powershell
kubectl apply -f k8s/samples/echo/ing.yaml
```

## Validate

```powershell
make echo-ingress-check
```

Direct commands:

```powershell
kubectl get ingress echo -n platform
kubectl describe ingress echo -n platform
kubectl get ingress echo -n platform -o jsonpath="{.status.loadBalancer.ingress[0].hostname}{'\n'}"
```

When a hostname appears:

```powershell
curl http://<alb-dns-name>/
```

Expected response:

```text
cpemon platform echo ok
```

## AWS-Side Checks

If Kubernetes shows the Ingress but no endpoint appears:

```powershell
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=100
```

Then check AWS:

```powershell
aws elbv2 describe-load-balancers --region eu-north-1 --profile cpemon-terraform
aws elbv2 describe-target-groups --region eu-north-1 --profile cpemon-terraform
aws elbv2 describe-target-health --target-group-arn <target-group-arn> --region eu-north-1 --profile cpemon-terraform
```

## Troubleshooting

Common failure paths:

- AWS Load Balancer Controller is not running.
- Controller service account lacks IAM permissions.
- Public subnets are not tagged for internet-facing load balancers.
- IngressClass is not `alb`.
- Service selector does not produce endpoints.
- Pod readiness probe is failing.
- Target group health check path or port is wrong.
- Security groups block traffic.
