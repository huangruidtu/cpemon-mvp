$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

function Invoke-Check {
    param([string]$RelativePath)
    $scriptPath = Join-Path $root $RelativePath
    if (!(Test-Path $scriptPath)) { throw "Expected validation script to exist: $scriptPath" }
    Write-Host "Running $RelativePath"
    & powershell -ExecutionPolicy Bypass -File $scriptPath
}

function Assert-Exists {
    param([string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (!(Test-Path $path)) { throw "Expected path to exist: $RelativePath" }
}

$requiredPaths = @(
    "k8s/addons/crossplane/values.yaml",
    "k8s/gitops/dev/applications/crossplane-dev.yaml",
    "k8s/gitops/dev/applications/crossplane-providers-dev.yaml",
    "k8s/crossplane/providers/aws/provider-family-aws.yaml",
    "k8s/crossplane/providers/aws/provider-services.yaml",
    "k8s/crossplane/providers/aws/providerconfig.yaml",
    "k8s/crossplane/functions/function-patch-and-transform.yaml",
    "k8s/crossplane/platform-api-conventions.md",
    "k8s/crossplane/platform-apis/s3/xrd.yaml",
    "k8s/crossplane/platform-apis/s3/composition.yaml",
    "k8s/crossplane/platform-apis/dynamodb/xrd.yaml",
    "k8s/crossplane/platform-apis/dynamodb/composition.yaml",
    "k8s/crossplane/platform-apis/ecr/xrd.yaml",
    "k8s/crossplane/platform-apis/ecr/composition.yaml",
    "k8s/crossplane/claims/dev/cpemon-api/kustomization.yaml",
    "k8s/policies/kyverno/crossplane/require-crossplane-request-guardrails.yaml",
    "k8s/crossplane/consumption/cpemon-api-infra-outputs-example.yaml",
    "docs/knowledge/crossplane-developer-self-service.md",
    "docs/knowledge/interview/story-21-crossplane-developer-self-service.md"
)

foreach ($path in $requiredPaths) {
    Assert-Exists $path
}

$checks = @(
    "scripts/verify-crossplane-terraform-boundary.ps1",
    "scripts/verify-argocd-crossplane-installation.ps1",
    "scripts/verify-crossplane-aws-provider-irsa.ps1",
    "scripts/verify-crossplane-platform-api-conventions.ps1",
    "scripts/verify-crossplane-s3-bucket-platform-api.ps1",
    "scripts/verify-crossplane-dynamodb-table-platform-api.ps1",
    "scripts/verify-crossplane-ecr-repository-platform-api.ps1",
    "scripts/verify-crossplane-developer-requests.ps1",
    "scripts/verify-argocd-crossplane-wiring.ps1",
    "scripts/verify-crossplane-policy-guardrails.ps1",
    "scripts/verify-crossplane-connection-outputs.ps1"
)

foreach ($check in $checks) {
    Invoke-Check $check
}

Write-Host "Crossplane story offline validation passed."
