$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$chartPath = Join-Path $root "deploy/helm/cpemon"
$templatePath = Join-Path $chartPath "templates/analysis-templates.yaml"
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

Assert-File $templatePath
Assert-File $valuesPath
Assert-File $schemaPath
Assert-File $chartReadmePath
Assert-File $knowledgePath
Assert-File $interviewPath

foreach ($needle in @(
    "cpemon-api-http-5xx-rate",
    "cpemon_api_http_requests_total",
    'code=~"5.."',
    "successCondition",
    "result[0] < 0.05",
    "prometheus"
)) {
    Assert-Contains $valuesPath $needle
}
Assert-Contains $templatePath "kind: AnalysisTemplate"
Assert-Contains $templatePath "provider:"
Assert-Contains $templatePath "prometheus:"
Assert-Contains $schemaPath '"rolloutAnalysis"'
Assert-Contains $chartReadmePath "Rollout AnalysisTemplates"
Assert-Contains $knowledgePath "CCPU-189: Add Prometheus AnalysisTemplate for HTTP 5xx Rate"
Assert-Contains $interviewPath "Q20: Why use HTTP 5xx rate as the first analysis signal?"

$rendered = & helm template cpemon $chartPath -n cpemon -f $devValuesPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "helm template failed: $rendered"
}

$renderedText = $rendered -join "`n"
$documents = $renderedText -split "(?m)^---\s*$"
$analysisTemplate = $documents | Where-Object {
    $_.Contains("kind: AnalysisTemplate") -and $_.Contains('name: "cpemon-api-http-5xx-rate"')
}
if (-not $analysisTemplate) {
    throw "HTTP 5xx AnalysisTemplate was not rendered."
}

$analysisText = $analysisTemplate -join "`n"
foreach ($needle in @("provider:", "prometheus:", "cpemon_api_http_requests_total", 'code=~"5.."', "result[0] < 0.05")) {
    if (-not $analysisText.Contains($needle)) {
        throw "Rendered AnalysisTemplate missing: $needle"
    }
}

Write-Host "CPEmon API HTTP 5xx AnalysisTemplate validation passed."
