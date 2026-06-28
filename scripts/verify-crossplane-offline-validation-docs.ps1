$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$storyScriptPath = Join-Path $root "scripts/verify-crossplane-story.ps1"
$runbookPath = Join-Path $root "ops/runbooks/crossplane-offline-validation.md"
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

foreach ($path in @($storyScriptPath, $runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-Exists $path
}

Assert-Contains $storyScriptPath "verify-crossplane-terraform-boundary.ps1"
Assert-Contains $storyScriptPath "verify-crossplane-connection-outputs.ps1"
Assert-Contains $storyScriptPath "Crossplane story offline validation passed"
Assert-Contains $runbookPath "Crossplane Offline Validation Runbook"
Assert-Contains $runbookPath "What It Does Not Prove"
Assert-Contains $knowledgePath "CCPU-227: Offline Validation for Crossplane Manifests"
Assert-Contains $interviewPath "Q37: What did CCPU-227 add?"
Assert-Contains $readmePath "Crossplane Offline Validation Runbook"
Assert-Contains $makefilePath "crossplane-story-check"
Assert-Contains $makefilePath "crossplane-offline-validation-docs-check"

Write-Host "Crossplane offline validation docs validation passed."
