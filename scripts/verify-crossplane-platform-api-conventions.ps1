$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$contractPath = Join-Path $root "k8s/crossplane/platform-api-conventions.md"
$runbookPath = Join-Path $root "ops/runbooks/crossplane-platform-api-conventions.md"
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

foreach ($path in @($contractPath, $runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-Exists $path
}

Assert-Contains $contractPath "API group: platform.cpemon.io"
Assert-Contains $contractPath "Version:   v1alpha1"
Assert-Contains $contractPath "XCPemonBucket"
Assert-Contains $contractPath "CPemonBucketClaim"
Assert-Contains $contractPath "cpemon.io/cost-center"
Assert-Contains $contractPath "providerConfigRef"
Assert-Contains $contractPath "aws-dev-irsa"
Assert-Contains $contractPath "Resource classes"

Assert-Contains $runbookPath "Crossplane Platform API Conventions Runbook"
Assert-Contains $runbookPath "small developer claim -> platform-owned XRD -> platform-owned Composition"
Assert-Contains $runbookPath "Live validation starts after concrete"

Assert-Contains $knowledgePath "CCPU-219: Platform API Conventions and Guardrails"
Assert-Contains $interviewPath "Q14: What did CCPU-219 add?"
Assert-Contains $readmePath "Crossplane Platform API Conventions Runbook"
Assert-Contains $makefilePath "crossplane-platform-api-conventions-check"

Write-Host "Crossplane platform API conventions validation passed."
