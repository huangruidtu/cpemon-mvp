$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbookPath = Join-Path $root "ops/runbooks/cpemon-api-prometheus-analysis-inputs.md"
$knowledgePath = Join-Path $root "docs/knowledge/argo-rollouts-canary-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-19-argo-rollouts-canary-deployment.md"
$indexPath = Join-Path $root "docs/knowledge/README.md"
$valuesPath = Join-Path $root "deploy/helm/cpemon/values.yaml"
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

foreach ($path in @($runbookPath, $knowledgePath, $interviewPath, $indexPath, $valuesPath)) {
    Assert-File $path
}

foreach ($needle in @(
    "CPEmon API Prometheus Analysis Inputs",
    "cpemon_api_http_requests_total",
    "cpemon_api_http_request_duration_seconds_bucket",
    'method`, `route`, `code',
    "Offline Validation",
    "Live Prometheus Checks",
    'sum(rate(cpemon_api_http_requests_total{code=~"5.."}[2m]))',
    "histogram_quantile(",
    "not empty vectors",
    "Route labels look like templates"
)) {
    Assert-Contains $runbookPath $needle
}

foreach ($needle in @(
    "cpemon_api_http_requests_total",
    "cpemon_api_http_request_duration_seconds_bucket",
    "clamp_min(sum(rate(cpemon_api_http_requests_total[2m])), 1)",
    "histogram_quantile("
)) {
    Assert-Contains $valuesPath $needle
}

Assert-Contains $knowledgePath "CCPU-197: Prometheus Metrics and Query Inputs"
Assert-Contains $interviewPath "Q48: What do you validate before trusting Prometheus AnalysisTemplates?"
Assert-Contains $interviewPath "Q49: Why is metric cardinality part of canary safety?"
Assert-Contains $indexPath "CPEmon API Prometheus Analysis Inputs"

$rendered = & helm template cpemon $chartPath -n cpemon -f $devValuesPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "helm template failed: $rendered"
}
$renderedText = $rendered -join "`n"
foreach ($needle in @(
    "kind: AnalysisTemplate",
    "cpemon-api-http-5xx-rate",
    "cpemon-api-p95-latency",
    "cpemon_api_http_requests_total",
    "cpemon_api_http_request_duration_seconds_bucket"
)) {
    if (-not $renderedText.Contains($needle)) {
        throw "Rendered chart missing Prometheus analysis input: $needle"
    }
}

Write-Host "CPEmon API Prometheus analysis input validation passed."
