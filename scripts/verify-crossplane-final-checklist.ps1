$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$checklistPath = Join-Path $root "ops/runbooks/crossplane-story-final-checklist.md"
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

foreach ($path in @($checklistPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-Exists $path
}

Assert-Contains $checklistPath "Crossplane Developer Self-Service Final Checklist"
Assert-Contains $checklistPath "Implemented Framework"
Assert-Contains $checklistPath "Offline Validation"
Assert-Contains $checklistPath "Live Validation Boundary"
Assert-Contains $checklistPath "Final Interview Summary"
Assert-Contains $checklistPath "Terraform still owns the EKS foundation"
Assert-Contains $knowledgePath "CCPU-230: Final Checklist and Live Validation Boundary"
Assert-Contains $interviewPath "Q46: What did CCPU-230 add?"
Assert-Contains $readmePath "Crossplane Developer Self-Service Final Checklist"
Assert-Contains $makefilePath "crossplane-final-checklist-check"

Write-Host "Crossplane final checklist validation passed."
