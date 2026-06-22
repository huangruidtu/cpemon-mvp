$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$chartPath = Join-Path $root "deploy/helm/cpemon"
$workloadsTemplatePath = Join-Path $chartPath "templates/workloads.yaml"
$valuesPath = Join-Path $chartPath "values.yaml"
$devValuesPath = Join-Path $chartPath "values-dev.yaml"
$schemaPath = Join-Path $chartPath "values.schema.json"
$chartReadmePath = Join-Path $chartPath "README.md"
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

Assert-File $workloadsTemplatePath
Assert-File $valuesPath
Assert-File $devValuesPath
Assert-File $schemaPath
Assert-File $chartReadmePath
Assert-File $knowledgePath
Assert-File $interviewPath

Assert-Contains $workloadsTemplatePath '$useRollout := and (eq $name "cpemonApi")'
Assert-Contains $workloadsTemplatePath 'apiVersion: {{ ternary "argoproj.io/v1alpha1" "apps/v1" $useRollout }}'
Assert-Contains $workloadsTemplatePath 'kind: {{ ternary "Rollout" "Deployment" $useRollout }}'
Assert-Contains $workloadsTemplatePath "strategy:"
Assert-Contains $workloadsTemplatePath "steps: []"
Assert-Contains $valuesPath "rollout:"
Assert-Contains $valuesPath "enabled: false"
Assert-Contains $devValuesPath "rollout:"
Assert-Contains $devValuesPath "enabled: true"
Assert-Contains $schemaPath '"rollout"'
Assert-Contains $schemaPath '"strategy"'
Assert-Contains $chartReadmePath "cpemon-api Rollout Mode"
Assert-Contains $knowledgePath "CCPU-115: Replace cpemon-api Deployment with Rollout"
Assert-Contains $interviewPath "Q11: Why migrate only cpemon-api to Rollout first?"

$rendered = & helm template cpemon $chartPath -n cpemon -f $devValuesPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "helm template failed: $rendered"
}

$renderedText = $rendered -join "`n"
$documents = $renderedText -split "(?m)^---\s*$"

$cpemonApiRollout = $documents | Where-Object {
    $_.Contains("kind: Rollout") -and $_.Contains('name: "cpemon-api"')
}
$cpemonApiDeployment = $documents | Where-Object {
    $_.Contains("kind: Deployment") -and $_.Contains('name: "cpemon-api"')
}
$acsIngestDeployment = $documents | Where-Object {
    $_.Contains("kind: Deployment") -and $_.Contains('name: "acs-ingest"')
}
$cpemonWriterDeployment = $documents | Where-Object {
    $_.Contains("kind: Deployment") -and $_.Contains('name: "cpemon-writer"')
}
$cpemonApiService = $documents | Where-Object {
    $_.Contains("kind: Service") -and $_.Contains('name: "cpemon-api"')
}

if (-not $cpemonApiRollout) {
    throw "cpemon-api did not render as a Rollout."
}
if ($cpemonApiDeployment) {
    throw "cpemon-api rendered as a Deployment while rollout mode is enabled."
}
if (-not $acsIngestDeployment) {
    throw "acs-ingest did not remain a Deployment."
}
if (-not $cpemonWriterDeployment) {
    throw "cpemon-writer did not remain a Deployment."
}
if (-not $cpemonApiService) {
    throw "cpemon-api Service was not rendered."
}
if (-not $renderedText.Contains("kind: ServiceMonitor")) {
    throw "ServiceMonitor was not rendered for dev values."
}

Write-Host "CPEmon API Rollout rendering validation passed."
