$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$adrPath = Join-Path $root "ADR/cloud-platform-upgrade-argo-rollouts-canary-deployment.md"
$runbookPath = Join-Path $root "ops/runbooks/argo-rollouts-cpemon-api.md"
$knowledgePath = Join-Path $root "docs/knowledge/argo-rollouts-canary-deployment.md"
$knowledgeIndexPath = Join-Path $root "docs/knowledge/README.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-19-argo-rollouts-canary-deployment.md"
$interviewIndexPath = Join-Path $root "docs/knowledge/interview/README.md"
$healthyDemoPath = Join-Path $root "ops/demos/argo-rollouts/cpemon-api-healthy-canary.md"
$failedDemoPath = Join-Path $root "ops/demos/argo-rollouts/cpemon-api-failed-canary.md"

function Assert-File {
    param([string] $Path)
    if (-not (Test-Path $Path)) {
        throw "Missing required file: $Path"
    }
}

function Assert-Contains {
    param(
        [string] $Path,
        [string] $Needle
    )
    $content = Get-Content -Raw $Path
    if (-not $content.Contains($Needle)) {
        throw "Expected '$Path' to contain '$Needle'"
    }
}

foreach ($path in @(
    $adrPath,
    $runbookPath,
    $knowledgePath,
    $knowledgeIndexPath,
    $interviewPath,
    $interviewIndexPath,
    $healthyDemoPath,
    $failedDemoPath
)) {
    Assert-File $path
}

foreach ($needle in @(
    "ADR: Argo Rollouts Canary Deployment for CPEmon API",
    'Use Argo Rollouts for `cpemon-api` canary deployment',
    "Stable and canary Services",
    "Prometheus AnalysisTemplates",
    "Rollback Behavior",
    "Abort is operator-first"
)) {
    Assert-Contains $adrPath $needle
}

foreach ($needle in @(
    "CCPU-196: Rollback and Incident Response",
    "kubectl argo rollouts abort cpemon-api -n cpemon",
    "git revert <bad-release-commit>",
    "Incident response checklist",
    "ADR/cloud-platform-upgrade-argo-rollouts-canary-deployment.md"
)) {
    Assert-Contains $runbookPath $needle
}

Assert-Contains $knowledgePath "CCPU-196: Rollback, ADR, Runbook, and Interview Notes"
Assert-Contains $knowledgeIndexPath "Argo Rollouts Canary Deployment Decision"
Assert-Contains $knowledgeIndexPath "Argo Rollouts CPEmon API Runbook"
Assert-Contains $interviewIndexPath "Story 19: Argo Rollouts Canary Deployment"
Assert-Contains $interviewPath "Q45: What is the difference between abort and rollback?"
Assert-Contains $interviewPath "Q47: What is the final Story 19 interview summary?"
Assert-Contains $healthyDemoPath "scripts/demo-cpemon-api-successful-rollout.ps1"
Assert-Contains $failedDemoPath "scripts/demo-cpemon-api-failed-rollout.ps1"

Write-Host "Argo Rollouts final docs validation passed."
