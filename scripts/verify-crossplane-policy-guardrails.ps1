$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$policyPath = Join-Path $root "k8s/policies/kyverno/crossplane/require-crossplane-request-guardrails.yaml"
$validPath = Join-Path $root "k8s/policies/kyverno/fixtures/valid/crossplane-bucket-request.yaml"
$invalidCostPath = Join-Path $root "k8s/policies/kyverno/fixtures/invalid/crossplane-missing-cost-center.yaml"
$invalidRegionPath = Join-Path $root "k8s/policies/kyverno/fixtures/invalid/crossplane-unapproved-region.yaml"
$invalidEcrPath = Join-Path $root "k8s/policies/kyverno/fixtures/invalid/crossplane-mutable-ecr.yaml"
$policyReadmePath = Join-Path $root "k8s/policies/kyverno/README.md"
$runbookPath = Join-Path $root "ops/runbooks/crossplane-policy-guardrails.md"
$knowledgePath = Join-Path $root "docs/knowledge/crossplane-developer-self-service.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-21-crossplane-developer-self-service.md"
$readmePath = Join-Path $root "docs/knowledge/README.md"
$makefilePath = Join-Path $root "Makefile"

function Assert-Exists {
    param([string]$Path)
    if (!(Test-Path $Path)) { throw "Expected file to exist: $Path" }
}

function Assert-Contains {
    param([string]$Path, [string]$Needle)
    $content = Get-Content $Path -Raw
    if ($content -notlike "*$Needle*") { throw "Expected '$Path' to contain '$Needle'" }
}

foreach ($path in @($policyPath, $validPath, $invalidCostPath, $invalidRegionPath, $invalidEcrPath, $policyReadmePath, $runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-Exists $path
}

Assert-Contains $policyPath "kind: ClusterPolicy"
Assert-Contains $policyPath "name: cpemon-crossplane-request-guardrails"
Assert-Contains $policyPath "validationFailureAction: Enforce"
Assert-Contains $policyPath "platform.cpemon.io/v1alpha1/XCPemonBucket"
Assert-Contains $policyPath "platform.cpemon.io/v1alpha1/XCPemonDynamoTable"
Assert-Contains $policyPath "platform.cpemon.io/v1alpha1/XCPemonECRRepository"
Assert-Contains $policyPath "cpemon.io/cost-center"
Assert-Contains $policyPath "eu-north-1"
Assert-Contains $policyPath "imageTagMutability: IMMUTABLE"
Assert-Contains $policyPath "scanOnPush: true"

Assert-Contains $validPath "cpemon.io/cost-center: learning"
Assert-Contains $invalidCostPath "invalid-crossplane-missing-cost-center"
Assert-Contains $invalidRegionPath "region: ap-southeast-2"
Assert-Contains $invalidEcrPath "imageTagMutability: MUTABLE"
Assert-Contains $policyReadmePath "require-crossplane-request-guardrails.yaml"
Assert-Contains $runbookPath "Crossplane Policy Guardrails Runbook"
Assert-Contains $knowledgePath "CCPU-225: Crossplane Policy Guardrails"
Assert-Contains $interviewPath "Q31: What did CCPU-225 add?"
Assert-Contains $readmePath "Crossplane Policy Guardrails Runbook"
Assert-Contains $makefilePath "crossplane-policy-guardrails-check"

Write-Host "Crossplane policy guardrails validation passed."
