$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$chartPath = Join-Path $root "deploy/helm/cpemon"
$valuesPath = Join-Path $chartPath "values.yaml"
$chartReadmePath = Join-Path $chartPath "README.md"
$knowledgePath = Join-Path $root "docs/knowledge/argo-rollouts-canary-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-19-argo-rollouts-canary-deployment.md"
$runbookPath = Join-Path $root "ops/runbooks/cpemon-api-analysis-wiring.md"
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
Assert-File $chartReadmePath
Assert-File $knowledgePath
Assert-File $interviewPath
Assert-File $runbookPath

foreach ($needle in @("analysis:", "templateName: cpemon-api-http-5xx-rate", "templateName: cpemon-api-p95-latency")) {
    Assert-Contains $valuesPath $needle
    Assert-Contains $chartReadmePath $needle
    Assert-Contains $knowledgePath $needle
}
Assert-Contains $knowledgePath "CCPU-191: Connect AnalysisTemplates to Rollout"
Assert-Contains $knowledgePath "CCPU-123: Connect AnalysisTemplates to Rollout"
Assert-Contains $interviewPath "Q26: Where did you attach the analysis gates?"
Assert-Contains $interviewPath "Q28: What is an AnalysisRun?"
Assert-Contains $interviewPath "Q54: What is the relationship between Rollout, AnalysisTemplate, and AnalysisRun?"
Assert-Contains $interviewPath "Q55: Why place analysis after pause windows?"
Assert-Contains $runbookPath "CPEmon API Rollout Analysis Wiring Runbook"
Assert-Contains $runbookPath "Rollout is the workflow"
Assert-Contains $runbookPath "each template is referenced twice"

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
foreach ($needle in @(
    "setWeight: 20",
    "duration: 60s",
    "analysis:",
    "templateName: cpemon-api-http-5xx-rate",
    "templateName: cpemon-api-p95-latency",
    "setWeight: 50",
    "duration: 120s",
    "setWeight: 100"
)) {
    if (-not $rolloutText.Contains($needle)) {
        throw "Rendered Rollout missing analysis wiring text: $needle"
    }
}

$httpTemplateRefs = ([regex]::Matches($rolloutText, "templateName: cpemon-api-http-5xx-rate")).Count
$p95TemplateRefs = ([regex]::Matches($rolloutText, "templateName: cpemon-api-p95-latency")).Count
if ($httpTemplateRefs -ne 2) {
    throw "Expected two HTTP 5xx template references in the Rollout, found $httpTemplateRefs."
}
if ($p95TemplateRefs -ne 2) {
    throw "Expected two p95 latency template references in the Rollout, found $p95TemplateRefs."
}

foreach ($templateName in @("cpemon-api-http-5xx-rate", "cpemon-api-p95-latency")) {
    $analysisTemplate = $documents | Where-Object {
        $_.Contains("kind: AnalysisTemplate") -and $_.Contains("name: `"$templateName`"")
    }
    if (-not $analysisTemplate) {
        throw "Rollout references missing AnalysisTemplate: $templateName"
    }
}

Write-Host "CPEmon API Rollout analysis wiring validation passed."
