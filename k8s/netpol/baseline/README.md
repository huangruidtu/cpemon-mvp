# Baseline NetworkPolicy Approach

This folder belongs to `CCPU-152`.

The files here are intentionally staged as candidate policies. They are not wired into an automatic apply target because NetworkPolicy enforcement depends on the cluster CNI configuration.

## Current Decision

Start with documentation, inspection commands, and one candidate CPEmon egress baseline.

Do not enforce broad default-deny across platform namespaces yet.

## Why Conservative

NetworkPolicy is powerful and easy to over-apply. A broad default-deny policy can break:

- DNS
- metrics-server checks
- AWS Load Balancer Controller webhooks or health paths
- future Argo CD sync operations
- observability scraping
- echo smoke tests

## Candidate Policy

```text
cpemon-egress-baseline-candidate.yaml
```

It models:

- default-deny egress for `cpemon`
- allow DNS to kube-dns/CoreDNS
- allow selected CPEmon app pods to reach MySQL
- allow selected CPEmon app pods to reach Prometheus in `monitoring`

## Validation

```powershell
make netpol-check
make netpol-baseline-plan
```

Apply only after confirming:

- EKS cluster exists
- VPC CNI NetworkPolicy enforcement is enabled, or a policy-capable CNI such as Calico/Cilium is installed
- namespace labels exist
- workload labels match policy selectors
- DNS and monitoring access are explicitly allowed
