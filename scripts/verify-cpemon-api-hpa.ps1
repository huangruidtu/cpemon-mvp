$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$chartPath = Join-Path $root "deploy/helm/cpemon"
$valuesPath = Join-Path $chartPath "values.yaml"
$devValuesPath = Join-Path $chartPath "values-dev.yaml"
$schemaPath = Join-Path $chartPath "values.schema.json"
$hpaTemplatePath = Join-Path $chartPath "templates/hpa.yaml"
$runbookPath = Join-Path $root "ops/runbooks/cpemon-api-hpa.md"
$knowledgePath = Join-Path $root "docs/knowledge/platform-governance-cost-autoscaling.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-20-platform-governance-cost-autoscaling.md"
$readmePath = Join-Path $root "docs/knowledge/README.md"

function Assert-File {
    param([string] $Path)
    if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
}

function Assert-Contains {
    param([string] $Path, [string] $Needle)
    $content = Get-Content -Raw $Path
    if ($content -notlike "*$Needle*") { throw "Expected '$Path' to contain '$Needle'" }
}

foreach ($path in @($valuesPath, $devValuesPath, $schemaPath, $hpaTemplatePath, $runbookPath, $knowledgePath, $interviewPath, $readmePath)) {
    Assert-File $path
}

Assert-Contains $valuesPath "autoscaling:"
Assert-Contains $valuesPath "targetCPUUtilizationPercentage: 70"
Assert-Contains $devValuesPath "autoscaling:"
Assert-Contains $devValuesPath "enabled: true"
Assert-Contains $schemaPath "targetCPUUtilizationPercentage"
Assert-Contains $hpaTemplatePath "kind: HorizontalPodAutoscaler"
Assert-Contains $hpaTemplatePath "scaleTargetRef:"
Assert-Contains $hpaTemplatePath 'ternary "Rollout" "Deployment"'
Assert-Contains $hpaTemplatePath "averageUtilization:"
Assert-Contains $runbookPath "cpemon-api HPA Runbook"
Assert-Contains $runbookPath "scaleTargetRef kind Rollout"
Assert-Contains $knowledgePath "CCPU-209: cpemon-api HPA Template and Values"
Assert-Contains $interviewPath "Q39: What did CCPU-209 add?"
Assert-Contains $readmePath "cpemon-api HPA Runbook"

$helm = Get-Command helm -ErrorAction SilentlyContinue
if (-not $helm) {
    throw "helm is required for this validation."
}

$render = & helm template cpemon $chartPath -n cpemon -f $devValuesPath
if ($LASTEXITCODE -ne 0) {
    throw "helm template failed for cpemon dev values."
}

$renderText = $render -join "`n"
foreach ($needle in @(
    "kind: HorizontalPodAutoscaler",
    'name: "cpemon-api-hpa"',
    "scaleTargetRef:",
    'apiVersion: "argoproj.io/v1alpha1"',
    'kind: "Rollout"',
    'name: "cpemon-api"',
    "minReplicas: 2",
    "maxReplicas: 4",
    "averageUtilization: 70"
)) {
    if ($renderText -notlike "*$needle*") {
        throw "Rendered cpemon chart did not contain expected HPA text: $needle"
    }
}

Write-Host "cpemon-api HPA validation passed."
