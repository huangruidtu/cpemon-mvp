# EKS NetworkPolicy Baseline Runbook

## Purpose

Use this runbook to inspect, dry-run, and eventually apply the CPEmon baseline NetworkPolicy approach.

This runbook belongs to `CCPU-152`.

## Current Boundary

The EKS cluster has not been applied yet. NetworkPolicy enforcement has not been enabled or validated on the target EKS cluster.

This task therefore defines the approach and candidate policy, but does not claim live enforcement.

## Why NetworkPolicy Needs a CNI

Kubernetes provides the `NetworkPolicy` API, but enforcement is done by the networking plugin.

On EKS, options include:

- Amazon VPC CNI with network policy support enabled
- Calico
- Cilium

If the cluster CNI does not enforce NetworkPolicy, the YAML can exist while traffic remains allowed.

## Baseline Decision

Do now:

- document the staged approach
- inspect policies with `kubectl get networkpolicy -A`
- prepare a CPEmon egress baseline candidate
- dry-run the candidate manifest

Do later:

- enable/confirm NetworkPolicy enforcement
- apply default-deny only to selected workload namespaces
- expand allow-list rules based on real workload communication

Do not do now:

- broad default-deny across all platform namespaces
- default-deny for `kube-system`
- default-deny for `platform`, `monitoring`, `argocd`, `security`, or `cost`

## Files

```text
k8s/netpol/baseline/README.md
k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml
```

## Inspect Existing Policies

```powershell
make netpol-check
```

Direct commands:

```powershell
kubectl get networkpolicy -A
kubectl describe networkpolicy -n cpemon
```

## Dry-Run Candidate

```powershell
make netpol-baseline-plan
```

Direct command:

```powershell
kubectl apply --dry-run=client -f k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml
```

## Apply Later

Only after enforcement is confirmed:

```powershell
kubectl apply -f k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml
```

## Troubleshooting

If a pod loses DNS:

```powershell
kubectl get networkpolicy -n cpemon
kubectl describe networkpolicy cpemon-allow-dns-egress -n cpemon
kubectl logs -n kube-system -l k8s-app=kube-dns
```

If a Service exists but traffic fails:

```powershell
kubectl get endpoints -n <namespace>
kubectl describe networkpolicy -n <namespace>
kubectl get pods -n <namespace> --show-labels
```

Most common policy issue:

```text
The NetworkPolicy podSelector or namespaceSelector does not match the actual labels.
```
