# Crossplane Policy Guardrails Runbook

This runbook documents the Kyverno policy layer for CPEmon Crossplane
developer requests.

## Policy

```text
k8s/policies/kyverno/crossplane/require-crossplane-request-guardrails.yaml
```

The policy applies to namespaced Crossplane platform API requests in the
`cpemon` namespace:

* `XCPemonBucket`
* `XCPemonDynamoTable`
* `XCPemonECRRepository`

## Guardrails

The policy enforces:

* standard app, environment, owner, and cost-center labels
* request provenance annotations
* approved environment/region/resourceClass/deletionPolicy combinations
* immutable tags and scan-on-push for ECR repositories

## Fixtures

Valid fixture:

```text
k8s/policies/kyverno/fixtures/valid/crossplane-bucket-request.yaml
```

Invalid fixtures:

```text
k8s/policies/kyverno/fixtures/invalid/crossplane-missing-cost-center.yaml
k8s/policies/kyverno/fixtures/invalid/crossplane-unapproved-region.yaml
k8s/policies/kyverno/fixtures/invalid/crossplane-mutable-ecr.yaml
```

## Local Validation

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-policy-guardrails.ps1
```

## Live Validation

After Kyverno and the Crossplane XRDs are installed:

```powershell
kubectl apply -f k8s/policies/kyverno/crossplane/require-crossplane-request-guardrails.yaml
kubectl apply -f k8s/policies/kyverno/fixtures/valid/crossplane-bucket-request.yaml
kubectl apply -f k8s/policies/kyverno/fixtures/invalid/crossplane-missing-cost-center.yaml
kubectl apply -f k8s/policies/kyverno/fixtures/invalid/crossplane-unapproved-region.yaml
kubectl apply -f k8s/policies/kyverno/fixtures/invalid/crossplane-mutable-ecr.yaml
```

The valid request should be accepted. The invalid requests should be denied by
Kyverno admission.

## Interview Answer

Say:

```text
I added Kyverno guardrails around Crossplane self-service because an abstraction
without admission control can still become unsafe. The policy requires owner and
cost metadata, restricts regions and deletion policy, and keeps ECR repositories
immutable and scanned.
```
