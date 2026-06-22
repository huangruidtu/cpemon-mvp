$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/opencost-dev.yaml"
$projectPath = Join-Path $root "k8s/addons/argocd/projects/cpemon-project.yaml"
$valuesPath = Join-Path $root "k8s/addons/opencost/values.yaml"
$runbookPath = Join-Path $root "ops/runbooks/argocd-opencost-installation.md"
$knowledgePath = Join-Path $root "docs/knowledge/platform-governance-cost-autoscaling.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-20-platform-governance-cost-autoscaling.md"

function Assert-File {
    param([string] $Path)
    if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
}

function Assert-Contains {
    param([string] $Path, [string] $Needle)
    $content = Get-Content -Raw $Path
    if ($content -notlike "*$Needle*") { throw "Expected '$Path' to contain '$Needle'" }
}

foreach ($path in @($applicationPath, $projectPath, $valuesPath, $runbookPath, $knowledgePath, $interviewPath)) {
    Assert-File $path
}

Assert-Contains $applicationPath "kind: Application"
Assert-Contains $applicationPath "name: opencost-dev"
Assert-Contains $applicationPath "repoURL: https://opencost.github.io/opencost-helm-chart"
Assert-Contains $applicationPath "chart: opencost"
Assert-Contains $applicationPath "targetRevision: 2.5.23"
Assert-Contains $applicationPath '$values/k8s/addons/opencost/values.yaml'
Assert-Contains $applicationPath "namespace: opencost"
Assert-Contains $applicationPath "cpemon.io/sync-policy: manual"

Assert-Contains $valuesPath "opencost:"
Assert-Contains $valuesPath "ui:"
Assert-Contains $valuesPath "service:"
Assert-Contains $valuesPath "type: ClusterIP"
Assert-Contains $projectPath "https://opencost.github.io/opencost-helm-chart"
Assert-Contains $projectPath "namespace: opencost"
Assert-Contains $runbookPath "visibility, not chargeback"
Assert-Contains $knowledgePath "CCPU-205: OpenCost Platform Installation"
Assert-Contains $interviewPath "Q27: What did CCPU-205 add?"

Write-Host "Argo CD OpenCost installation validation passed."
