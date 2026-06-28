$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbookPath = Join-Path $root "ops/runbooks/crossplane-lifecycle-update-delete-rollback.md"
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

foreach ($path in @($runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-Exists $path
}

Assert-Contains $runbookPath "Crossplane Lifecycle, Update, Deletion, and Rollback Runbook"
Assert-Contains $runbookPath "deletionPolicy: Orphan"
Assert-Contains $runbookPath "git revert <commit>"
Assert-Contains $runbookPath "Provider unhealthy"
Assert-Contains $runbookPath "Live Validation Boundary"
Assert-Contains $knowledgePath "CCPU-228: Lifecycle, Update, Deletion, and Rollback"
Assert-Contains $interviewPath "Q40: What did CCPU-228 add?"
Assert-Contains $readmePath "Crossplane Lifecycle, Update, Deletion, and Rollback Runbook"
Assert-Contains $makefilePath "crossplane-lifecycle-runbook-check"

Write-Host "Crossplane lifecycle runbook validation passed."
