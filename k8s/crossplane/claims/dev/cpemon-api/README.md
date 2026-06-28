# cpemon-api Developer Infrastructure Requests

This folder shows the CPEmon API team's dev environment self-service requests.

## Requests

| File | Platform API | Purpose |
| --- | --- | --- |
| `s3-artifacts-bucket.yaml` | `XCPemonBucket` | Store generated application artifacts or exports. |
| `dynamodb-health-table.yaml` | `XCPemonDynamoTable` | Store health/event lookup data for the application boundary. |
| `ecr-image-repository.yaml` | `XCPemonECRRepository` | Store immutable scanned container images. |

## Golden Path

```text
edit request YAML -> open PR -> platform review -> merge -> Argo CD sync -> Crossplane reconcile
```

Developers own the request intent. The platform owns the XRDs, Compositions,
ProviderConfig, IRSA boundary, and runtime guardrails.

## Local Validation

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-developer-requests.ps1
```
