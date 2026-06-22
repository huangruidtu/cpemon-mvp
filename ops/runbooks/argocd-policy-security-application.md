# Argo CD Policy and Security Application Runbook

This runbook validates the `policy-security-dev` Argo CD Application.

## Purpose

`policy-security-dev` brings the existing CPEmon NetworkPolicy baseline
candidate into the GitOps model.

```text
Application:    policy-security-dev
Project:        cpemon
Source repo:    https://github.com/huangruidtu/cpemon-mvp.git
Source path:    k8s/netpol/baseline
Destination:    https://kubernetes.default.svc / cpemon
```

The current policy boundary is intentionally small. It manages native
Kubernetes `NetworkPolicy` manifests for the CPEmon workload namespace.

## Current Scope

Included now:

```text
k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml
```

Deferred:

* Kyverno controller installation
* Kyverno policy resources
* OPA Gatekeeper
* broad platform namespace default-deny

Kyverno is deferred because the repository does not yet contain a pinned chart
version, values file, policy package, controller runbook, or validation script.
Adding it without those pieces would create a noisy policy platform instead of
a reviewable guardrail.

## Static Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-policy-security-application.ps1
```

When kubeconfig points to a reachable cluster API, validate the NetworkPolicy
manifest shape:

```powershell
kubectl apply --dry-run=client --validate=false `
  -f k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml
```

Note: `kubectl apply --dry-run=client` can still contact the API server for
discovery. If no cluster API is reachable, use the repository script above as
the offline validation boundary.

## Live Validation

Apply the Application after Argo CD and the `cpemon` AppProject exist:

```powershell
kubectl apply -f k8s/gitops/dev/applications/policy-security-dev.yaml
```

Inspect Argo CD state:

```powershell
kubectl get application policy-security-dev -n argocd
kubectl describe application policy-security-dev -n argocd
```

If the Argo CD CLI is installed:

```powershell
argocd app get policy-security-dev
```

Inspect NetworkPolicies:

```powershell
kubectl get networkpolicy -n cpemon
kubectl describe networkpolicy -n cpemon
```

## Enforcement Warning

Kubernetes accepts `NetworkPolicy` objects even when the cluster networking
layer does not enforce them.

Before relying on the baseline:

* confirm the EKS CNI network policy mode or selected policy engine
* confirm workload labels match the policy selectors
* confirm DNS egress works
* test MySQL and monitoring connectivity from selected CPEmon pods
* avoid broad default-deny in platform namespaces until traffic is mapped

## Expected State

`Synced` means Argo CD applied the NetworkPolicy objects.

`Healthy` does not prove enforcement. For NetworkPolicy, the real proof is a
connectivity test showing allowed traffic succeeds and denied traffic fails.

## Interview Framing

Platform guardrails differ from app manifests because they constrain behavior
instead of only deploying workloads. They should be introduced gradually,
validated against real traffic, and documented with rollback and troubleshooting
steps. A staged NetworkPolicy baseline is safer than turning on broad admission
or network restrictions before the platform is observable.
