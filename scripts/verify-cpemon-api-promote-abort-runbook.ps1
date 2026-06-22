$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbookPath = Join-Path $root "ops/runbooks/argo-rollouts-cpemon-api.md"
$knowledgePath = Join-Path $root "docs/knowledge/argo-rollouts-canary-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-19-argo-rollouts-canary-deployment.md"

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

Assert-File $runbookPath
Assert-File $knowledgePath
Assert-File $interviewPath

foreach ($needle in @(
    "CCPU-119: Manual Promote and Abort",
    "kubectl argo rollouts promote cpemon-api -n cpemon",
    "kubectl argo rollouts promote cpemon-api -n cpemon --full",
    "kubectl argo rollouts abort cpemon-api -n cpemon",
    "Promote Decision",
    "Abort Decision",
    "Expected Demo Behavior",
    "AnalysisRuns passed",
    "5xx ratio is below the threshold",
    "p95 latency is below the threshold"
)) {
    Assert-Contains $runbookPath $needle
}

Assert-Contains $knowledgePath "CCPU-119: Test Manual Promote and Abort"
Assert-Contains $knowledgePath "kubectl argo rollouts promote cpemon-api -n cpemon"
Assert-Contains $knowledgePath "kubectl argo rollouts abort cpemon-api -n cpemon"
Assert-Contains $interviewPath "Q32: When would you manually promote?"
Assert-Contains $interviewPath 'Q34: Why is `promote --full` risky?'

Write-Host "CPEmon API promote/abort runbook validation passed."
