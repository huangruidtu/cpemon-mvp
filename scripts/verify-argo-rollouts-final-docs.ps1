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
$analysisTroubleshootingPath = Join-Path $root "ops/runbooks/cpemon-api-analysisrun-troubleshooting.md"

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
    $failedDemoPath,
    $analysisTroubleshootingPath
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
    "CCPU-126: Rollback Behavior",
    "kubectl argo rollouts abort cpemon-api -n cpemon",
    "git revert <bad-release-commit>",
    "Incident response checklist",
    "abort stops unsafe in-flight progression",
    "ADR/cloud-platform-upgrade-argo-rollouts-canary-deployment.md"
)) {
    Assert-Contains $runbookPath $needle
}

Assert-Contains $knowledgePath "CCPU-196: Rollback, ADR, Runbook, and Interview Notes"
Assert-Contains $knowledgePath "CCPU-126: Document Rollback Behavior"
Assert-Contains $knowledgePath "CCPU-198: AnalysisRun Troubleshooting and Interview Notes"
Assert-Contains $knowledgeIndexPath "Argo Rollouts Canary Deployment Decision"
Assert-Contains $knowledgeIndexPath "Argo Rollouts CPEmon API Runbook"
Assert-Contains $knowledgeIndexPath "CPEmon API AnalysisRun Troubleshooting"
Assert-Contains $interviewIndexPath "Story 19: Argo Rollouts Canary Deployment"
Assert-Contains $interviewPath "Q45: What is the difference between abort and rollback?"
Assert-Contains $interviewPath "Q47: What is the final Story 19 interview summary?"
Assert-Contains $interviewPath "Q59: How would you explain CPEmon rollback behavior?"
Assert-Contains $interviewPath "Q60: Why is Git-first rollback important in a GitOps platform?"
Assert-Contains $interviewPath "Q61: How do you troubleshoot a failed AnalysisRun?"
Assert-Contains $interviewPath "Q62: What causes missing Prometheus data during analysis?"
Assert-Contains $interviewPath "Q63: How do you explain false positives and false negatives in canary gates?"
Assert-Contains $healthyDemoPath "scripts/demo-cpemon-api-successful-rollout.ps1"
Assert-Contains $failedDemoPath "scripts/demo-cpemon-api-failed-rollout.ps1"

foreach ($needle in @(
    "CPEmon API AnalysisRun Troubleshooting",
    "Missing Prometheus Data",
    "False Positives and False Negatives",
    "unsafe user impact -> abort",
    "manifest, metric, and runtime"
)) {
    Assert-Contains $analysisTroubleshootingPath $needle
}

Write-Host "Argo Rollouts final docs validation passed."
