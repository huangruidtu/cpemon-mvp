$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbookPath = Join-Path $root "ops/runbooks/argocd-drift-detection-validation.md"
$knowledgePath = Join-Path $root "docs/knowledge/argocd-gitops-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-17-argocd-gitops-deployment.md"

foreach ($path in @($runbookPath, $knowledgePath, $interviewPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing drift validation file: $path"
    }
}

$runbook = Get-Content -Raw $runbookPath
foreach ($snippet in @(
    "Safe Drift Example",
    "kubectl -n cpemon annotate deployment cpemon-api",
    "argocd app diff cpemon-dev",
    "Sync Status: OutOfSync",
    "argocd app sync cpemon-dev",
    "Sync Status: Synced",
    "Recovery",
    "What This Proves",
    "What This Does Not Prove"
)) {
    if ($runbook -notlike "*$snippet*") {
        throw "Drift validation runbook is missing: $snippet"
    }
}

$knowledge = Get-Content -Raw $knowledgePath
if ($knowledge -notlike "*CCPU-179: Validate Manual Drift Detection and Self-Heal*") {
    throw "Knowledge notes missing CCPU-179 section."
}

$interview = Get-Content -Raw $interviewPath
if ($interview -notlike "*Q56: What did CCPU-179 add?*") {
    throw "Interview notes missing CCPU-179 question."
}

Write-Host "Argo CD drift detection validation documentation passed."
