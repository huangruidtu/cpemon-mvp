# Kyverno Baseline Resource Policy Runbook

This runbook validates the CPEmon resource requests and limits policy.

## Policy Contract

```text
Policy:       cpemon-require-container-resources
Kind:         ClusterPolicy
Path:         k8s/policies/kyverno/baseline/require-container-resources.yaml
Application:  kyverno-policies-dev
Namespace:    cpemon workloads are checked
Mode:         Enforce
```

The policy requires every container in a Pod created in the `cpemon` namespace
to define:

```text
resources.requests.cpu
resources.requests.memory
resources.limits.cpu
resources.limits.memory
```

## Why This Policy Exists

Requests and limits are not just resource hygiene.

They affect:

* scheduler placement
* node capacity planning
* OpenCost allocation signals
* HPA CPU utilization math
* blast radius when a container misbehaves

Without CPU requests, HPA cannot make meaningful CPU utilization decisions.
Without memory limits, a workload can consume more node memory than expected.

## GitOps Flow

Sync order:

1. `kyverno-dev`
2. `kyverno-policies-dev`
3. `cpemon-dev`

The controller must be healthy before the policy package is synced. CPEmon
workloads must satisfy the policy before they are synced or upgraded.

## Local Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-resource-policy.ps1
```

This validates:

* policy file exists
* policy is a Kyverno `ClusterPolicy`
* policy uses `Enforce`
* policy targets the `cpemon` namespace
* policy checks CPU and memory requests and limits
* the GitOps Application points at `k8s/policies/kyverno`
* knowledge and interview notes describe the decision

## Live Validation

After Kyverno is installed:

```powershell
kubectl apply -f k8s/gitops/dev/applications/kyverno-policies-dev.yaml
argocd app sync kyverno-policies-dev
argocd app wait kyverno-policies-dev --sync --health --timeout 300
kubectl get clusterpolicy cpemon-require-container-resources
kubectl describe clusterpolicy cpemon-require-container-resources
```

Try an invalid Pod:

```powershell
kubectl run missing-resources `
  -n cpemon `
  --image=busybox:1.36 `
  --restart=Never `
  -- sleep 3600
```

Expected result:

```text
admission webhook "validate.kyverno.svc" denied the request
```

Try a valid manifest with requests and limits:

```powershell
kubectl apply -n cpemon -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: valid-resources
spec:
  containers:
    - name: busybox
      image: busybox:1.36
      command: ["sleep", "3600"]
      resources:
        requests:
          cpu: 10m
          memory: 32Mi
        limits:
          cpu: 100m
          memory: 64Mi
EOF
```

Expected result:

```text
pod/valid-resources created
```

Clean up:

```powershell
kubectl delete pod valid-resources -n cpemon --ignore-not-found
```

## Rollback

Because the policy is enforced, a bad rule can block deployments.

Rollback path:

```powershell
git revert <policy-commit>
argocd app sync kyverno-policies-dev
argocd app wait kyverno-policies-dev --sync --health --timeout 300
```

For emergency dev-only relief, an operator can temporarily delete the
ClusterPolicy:

```powershell
kubectl delete clusterpolicy cpemon-require-container-resources
```

Turn any emergency deletion into a Git fix immediately.

## Interview Framing

The concise answer:

```text
I enforced CPU and memory requests and limits with Kyverno because those fields
connect scheduling, cost visibility, and HPA correctness. The policy is scoped
to CPEmon workloads first, and it is deployed separately from the Kyverno
controller so policy behavior can be reviewed and rolled back independently.
```
