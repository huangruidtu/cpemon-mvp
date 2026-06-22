$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbookPath = Join-Path $root "ops/runbooks/argo-rollouts-cpemon-api.md"
$knowledgePath = Join-Path $root "docs/knowledge/argo-rollouts-canary-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-19-argo-rollouts-canary-deployment.md"
$chartPath = Join-Path $root "deploy/helm/cpemon"
$devValuesPath = Join-Path $chartPath "values-dev.yaml"

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
    "kubectl argo rollouts get rollout cpemon-api -n cpemon",
    "kubectl get rollout cpemon-api -n cpemon -o yaml",
    "kubectl get rs,pods,svc,endpoints,analysisrun -n cpemon -l app=cpemon-api",
    "kubectl describe rollout cpemon-api -n cpemon",
    "Healthy",
    "Progressing",
    "Paused",
    "Degraded",
    "Aborted",
    "AnalysisRuns"
)) {
    Assert-Contains $runbookPath $needle
}
Assert-Contains $knowledgePath "CCPU-118: Verify Rollout Status with kubectl argo rollouts"
Assert-Contains $interviewPath "Q29: How do you verify rollout status?"
Assert-Contains $interviewPath "Q31: What is the difference between Paused, Degraded, and Aborted?"

$rendered = & helm template cpemon $chartPath -n cpemon -f $devValuesPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "helm template failed: $rendered"
}
$renderedText = $rendered -join "`n"
foreach ($needle in @(
    "kind: Rollout",
    'name: "cpemon-api"',
    "kind: AnalysisTemplate",
    'name: "cpemon-api-http-5xx-rate"',
    'name: "cpemon-api-p95-latency"'
)) {
    if (-not $renderedText.Contains($needle)) {
        throw "Rendered chart missing expected rollout status resource: $needle"
    }
}

Write-Host "CPEmon API rollout status runbook validation passed."
