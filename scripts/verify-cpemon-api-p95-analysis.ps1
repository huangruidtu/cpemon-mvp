$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$chartPath = Join-Path $root "deploy/helm/cpemon"
$templatePath = Join-Path $chartPath "templates/analysis-templates.yaml"
$valuesPath = Join-Path $chartPath "values.yaml"
$schemaPath = Join-Path $chartPath "values.schema.json"
$chartReadmePath = Join-Path $chartPath "README.md"
$knowledgePath = Join-Path $root "docs/knowledge/argo-rollouts-canary-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-19-argo-rollouts-canary-deployment.md"
$runbookPath = Join-Path $root "ops/runbooks/cpemon-api-p95-latency-analysis.md"
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

Assert-File $templatePath
Assert-File $valuesPath
Assert-File $schemaPath
Assert-File $chartReadmePath
Assert-File $knowledgePath
Assert-File $interviewPath
Assert-File $runbookPath

foreach ($needle in @(
    "cpemon-api-p95-latency",
    "cpemon_api_http_request_duration_seconds_bucket",
    "histogram_quantile",
    "sum by (le)",
    "result[0] < 0.5",
    "p95Latency"
)) {
    Assert-Contains $valuesPath $needle
}
Assert-Contains $templatePath "cpemon.io/analysis-signal: p95-latency"
Assert-Contains $schemaPath '"p95Latency"'
Assert-Contains $chartReadmePath "AnalysisTemplate/cpemon-api-p95-latency"
Assert-Contains $knowledgePath "CCPU-190: Add Prometheus AnalysisTemplate for p95 Latency"
Assert-Contains $knowledgePath "CCPU-122: Create AnalysisTemplate for p95 Latency"
Assert-Contains $interviewPath "Q23: Why add p95 latency analysis in addition to 5xx analysis?"
Assert-Contains $interviewPath "Q52: What exactly does the p95 latency AnalysisTemplate measure?"
Assert-Contains $interviewPath "Q53: Why is p95 better than average latency for canary gating?"
Assert-Contains $runbookPath "CPEmon API p95 Latency AnalysisTemplate Runbook"
Assert-Contains $runbookPath "histogram_quantile"
Assert-Contains $runbookPath "sum by (le)"
Assert-Contains $runbookPath "result[0] < 0.5"

$rendered = & helm template cpemon $chartPath -n cpemon -f $devValuesPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "helm template failed: $rendered"
}

$renderedText = $rendered -join "`n"
$documents = $renderedText -split "(?m)^---\s*$"
$analysisTemplate = $documents | Where-Object {
    $_.Contains("kind: AnalysisTemplate") -and $_.Contains('name: "cpemon-api-p95-latency"')
}
if (-not $analysisTemplate) {
    throw "p95 latency AnalysisTemplate was not rendered."
}

$analysisText = $analysisTemplate -join "`n"
foreach ($needle in @("provider:", "prometheus:", "histogram_quantile", "cpemon_api_http_request_duration_seconds_bucket", "result[0] < 0.5")) {
    if (-not $analysisText.Contains($needle)) {
        throw "Rendered p95 AnalysisTemplate missing: $needle"
    }
}

Write-Host "CPEmon API p95 latency AnalysisTemplate validation passed."
