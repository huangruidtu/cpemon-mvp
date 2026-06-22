$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$chartPath = Join-Path $root "deploy/helm/cpemon"
$workloadsTemplatePath = Join-Path $chartPath "templates/workloads.yaml"
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

Assert-File $workloadsTemplatePath
Assert-File $valuesPath
Assert-File $schemaPath
Assert-File $chartReadmePath
Assert-File $knowledgePath
Assert-File $interviewPath

Assert-Contains $valuesPath "cpemon-api-stable"
Assert-Contains $valuesPath "cpemon-api-canary"
Assert-Contains $workloadsTemplatePath "stableService:"
Assert-Contains $workloadsTemplatePath "canaryService:"
Assert-Contains $workloadsTemplatePath "cpemon.io/rollout-service: stable"
Assert-Contains $workloadsTemplatePath "cpemon.io/rollout-service: canary"
Assert-Contains $schemaPath '"rolloutService"'
Assert-Contains $chartReadmePath "Service/cpemon-api-stable"
Assert-Contains $knowledgePath "CCPU-116: Create Stable and Canary Services"
Assert-Contains $interviewPath "Q14: Why add stable and canary Services?"

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
foreach ($needle in @("stableService: `"cpemon-api-stable`"", "canaryService: `"cpemon-api-canary`"")) {
    if (-not ($rollout -join "`n").Contains($needle)) {
        throw "Rollout does not reference expected service: $needle"
    }
}

foreach ($serviceName in @("cpemon-api", "cpemon-api-stable", "cpemon-api-canary")) {
    $service = $documents | Where-Object {
        $_.Contains("kind: Service") -and $_.Contains("name: `"$serviceName`"")
    }
    if (-not $service) {
        throw "Missing expected Service: $serviceName"
    }
    $serviceText = $service -join "`n"
    foreach ($selector in @('app: "cpemon-api"', 'app.kubernetes.io/component: "api"', 'app.kubernetes.io/instance: "cpemon"')) {
        if (-not $serviceText.Contains($selector)) {
            throw "Service $serviceName is missing selector: $selector"
        }
    }
}

Write-Host "CPEmon API Rollout stable/canary service validation passed."
