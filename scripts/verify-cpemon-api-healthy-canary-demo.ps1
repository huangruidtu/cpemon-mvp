$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$demoPath = Join-Path $root "ops/demos/argo-rollouts/cpemon-api-healthy-canary.md"
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

Assert-File $demoPath
Assert-File $runbookPath
Assert-File $knowledgePath
Assert-File $interviewPath

foreach ($needle in @(
    "CPEmon API Healthy Canary Demo Scenario",
    "kubectl argo rollouts get rollout cpemon-api -n cpemon --watch",
    "kubectl get endpoints cpemon-api-stable cpemon-api-canary -n cpemon",
    "cpemon-api-http-5xx-rate and cpemon-api-p95-latency",
    "20% traffic",
    "50% traffic",
    "100% traffic",
    "AnalysisRuns are Successful",
    "new ReplicaSet is the stable ReplicaSet",
    "Interview Narrative"
)) {
    Assert-Contains $demoPath $needle
}

Assert-Contains $runbookPath "CCPU-192: Healthy Canary Demo Scenario"
Assert-Contains $runbookPath "ops/demos/argo-rollouts/cpemon-api-healthy-canary.md"
Assert-Contains $knowledgePath "CCPU-192: Healthy Canary Demo Scenario"
Assert-Contains $interviewPath "Q35: How would you demo a healthy canary rollout?"
Assert-Contains $interviewPath "Q37: Why is a healthy demo still valuable if nothing fails?"

$rendered = & helm template cpemon $chartPath -n cpemon -f $devValuesPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "helm template failed: $rendered"
}
$renderedText = $rendered -join "`n"
foreach ($needle in @(
    "kind: Rollout",
    'name: "cpemon-api"',
    "setWeight: 20",
    "setWeight: 50",
    "templateName: cpemon-api-http-5xx-rate",
    "templateName: cpemon-api-p95-latency"
)) {
    if (-not $renderedText.Contains($needle)) {
        throw "Rendered chart missing expected healthy canary contract: $needle"
    }
}

Write-Host "CPEmon API healthy canary demo validation passed."
