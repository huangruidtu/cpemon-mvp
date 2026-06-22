$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$chartPath = Join-Path $root "deploy/helm/cpemon"
$valuesPath = Join-Path $chartPath "values.yaml"
$schemaPath = Join-Path $chartPath "values.schema.json"
$chartReadmePath = Join-Path $chartPath "README.md"
$knowledgePath = Join-Path $root "docs/knowledge/argo-rollouts-canary-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-19-argo-rollouts-canary-deployment.md"
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

Assert-File $valuesPath
Assert-File $schemaPath
Assert-File $chartReadmePath
Assert-File $knowledgePath
Assert-File $interviewPath

foreach ($needle in @("setWeight: 20", "duration: 60s", "setWeight: 50", "duration: 120s", "setWeight: 100")) {
    Assert-Contains $valuesPath $needle
    Assert-Contains $chartReadmePath $needle
    Assert-Contains $knowledgePath $needle
}
Assert-Contains $schemaPath '"minProperties": 1'
Assert-Contains $knowledgePath "CCPU-117: Configure Canary Steps"
Assert-Contains $interviewPath "Q17: Why use 20%, pause, 50%, pause, 100%?"
Assert-Contains $interviewPath "Q19: Why not add Prometheus analysis in the same step?"

$rendered = & helm template cpemon $chartPath -n cpemon -f $devValuesPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "helm template failed: $rendered"
}

$renderedText = $rendered -join "`n"
$documents = $renderedText -split "(?m)^---\s*$"
$rollout = $documents | Where-Object {
    $_.Contains("kind: Rollout") -and $_.Contains('name: "cpemon-api"')
}
if (-not $rollout) {
    throw "cpemon-api Rollout was not rendered."
}

$rolloutText = $rollout -join "`n"
foreach ($needle in @("setWeight: 20", "duration: 60s", "setWeight: 50", "duration: 120s", "setWeight: 100")) {
    if (-not $rolloutText.Contains($needle)) {
        throw "Rendered Rollout is missing canary step: $needle"
    }
}

Write-Host "CPEmon API canary steps validation passed."
