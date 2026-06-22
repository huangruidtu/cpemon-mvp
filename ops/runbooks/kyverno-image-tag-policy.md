# Kyverno Image Tag Policy Runbook

This runbook validates the CPEmon image tag policy.

## Policy Contract

```text
Policy:       cpemon-disallow-latest-image-tag
Kind:         ClusterPolicy
Path:         k8s/policies/kyverno/baseline/disallow-latest-image-tag.yaml
Application:  kyverno-policies-dev
Namespace:    cpemon workloads are checked
Mode:         Enforce
```

The policy rejects Pods in the `cpemon` namespace when any container image ends
with:

```text
:latest
```

## Why This Policy Exists

The `latest` tag is mutable. The same Git commit can deploy different bits at
different times if the registry tag is overwritten.

That weakens:

* GitOps reproducibility
* incident rollback
* image provenance review
* audit trails
* canary and promotion explanations

For CPEmon, releases should use explicit image tags such as a Git SHA,
semantic version, build number, or digest. Digest-only enforcement is a stronger
future production option; the Step 1 baseline bans the most dangerous mutable
tag first.

## Local Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-image-tag-policy.ps1
```

## Live Validation

After Kyverno and the policy package are synced:

```powershell
kubectl get clusterpolicy cpemon-disallow-latest-image-tag
kubectl describe clusterpolicy cpemon-disallow-latest-image-tag
```

Try an invalid Pod:

```powershell
kubectl run latest-image `
  -n cpemon `
  --image=busybox:latest `
  --restart=Never `
  -- sleep 3600
```

Expected result:

```text
admission webhook "validate.kyverno.svc" denied the request
```

Try an explicit tag:

```powershell
kubectl run explicit-image `
  -n cpemon `
  --image=busybox:1.36 `
  --restart=Never `
  -- sleep 3600
```

If the resource policy from CCPU-201 is also enforced, use a manifest that
includes requests and limits. The image tag policy itself should not reject
`busybox:1.36`.

Clean up:

```powershell
kubectl delete pod explicit-image latest-image -n cpemon --ignore-not-found
```

## Rollback

If a release is blocked unexpectedly:

```powershell
git revert <policy-commit>
argocd app sync kyverno-policies-dev
argocd app wait kyverno-policies-dev --sync --health --timeout 300
```

Do not solve the problem by pushing over the `latest` tag. Use a new explicit
tag and update Git.

## Interview Framing

The concise answer:

```text
I banned the `latest` tag because GitOps depends on a commit mapping to a
repeatable desired state. A mutable image tag breaks rollback and auditability.
The first policy bans the riskiest tag while leaving digest-only enforcement as
a future production hardening step.
```
