# Kyverno Policy Fixtures Runbook

This runbook validates the CPEmon Kyverno policy fixture set.

## Fixture Inventory

Valid:

```text
k8s/policies/kyverno/fixtures/valid/cpemon-valid-pod.yaml
```

Invalid:

```text
k8s/policies/kyverno/fixtures/invalid/missing-resources.yaml
k8s/policies/kyverno/fixtures/invalid/latest-image.yaml
k8s/policies/kyverno/fixtures/invalid/missing-labels.yaml
k8s/policies/kyverno/fixtures/invalid/root-container.yaml
```

## Local Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-policy-fixtures.ps1
```

This is an offline repository check. It proves the examples exist and that each
fixture demonstrates the intended policy behavior.

## Live Validation

After `kyverno-dev` and `kyverno-policies-dev` are synced:

```powershell
kubectl get cpol
kubectl get policyreport -A
```

Apply the valid fixture:

```powershell
kubectl apply -f k8s/policies/kyverno/fixtures/valid/cpemon-valid-pod.yaml
kubectl delete -f k8s/policies/kyverno/fixtures/valid/cpemon-valid-pod.yaml --ignore-not-found
```

Try each invalid fixture:

```powershell
kubectl apply -f k8s/policies/kyverno/fixtures/invalid/missing-resources.yaml
kubectl apply -f k8s/policies/kyverno/fixtures/invalid/latest-image.yaml
kubectl apply -f k8s/policies/kyverno/fixtures/invalid/missing-labels.yaml
kubectl apply -f k8s/policies/kyverno/fixtures/invalid/root-container.yaml
```

Expected result:

```text
admission webhook "validate.kyverno.svc" denied the request
```

Then inspect reports:

```powershell
kubectl get policyreport -n cpemon
kubectl describe policyreport -n cpemon
```

## Interview Framing

Fixtures turn policy claims into evidence. Instead of only saying "we added
Kyverno," the project can show what is allowed, what is rejected, and how an
operator would inspect policy results through `ClusterPolicy` and
`PolicyReport`.
