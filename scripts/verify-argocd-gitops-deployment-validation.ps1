$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/cpemon-dev.yaml"
$chartPath = Join-Path $root "deploy/helm/cpemon"
$valuesPath = Join-Path $root "deploy/helm/cpemon/values-dev.yaml"
$runbookPath = Join-Path $root "ops/runbooks/argocd-gitops-deployment-validation.md"
$knowledgePath = Join-Path $root "docs/knowledge/argocd-gitops-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-17-argocd-gitops-deployment.md"

function Assert-Contains {
    param(
        [string] $Path,
        [string] $Needle
    )
    $content = Get-Content -Raw $Path
    if ($content -notlike "*$Needle*") {
        throw "Expected '$Path' to contain '$Needle'"
    }
}

foreach ($path in @($applicationPath, $valuesPath, $runbookPath, $knowledgePath, $interviewPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing required GitOps validation file: $path"
    }
}

if (-not (Test-Path (Join-Path $chartPath "Chart.yaml"))) {
    throw "Missing CPEmon Helm chart at $chartPath"
}

Assert-Contains $applicationPath "name: cpemon-dev"
Assert-Contains $applicationPath "repoURL: https://github.com/huangruidtu/cpemon-mvp.git"
Assert-Contains $applicationPath "targetRevision: HEAD"
Assert-Contains $applicationPath "path: deploy/helm/cpemon"
Assert-Contains $applicationPath "values-dev.yaml"
Assert-Contains $applicationPath "namespace: cpemon"
Assert-Contains $applicationPath "cpemon.io/sync-policy: manual"
Assert-Contains $runbookPath "argocd app get cpemon-dev"
Assert-Contains $runbookPath "argocd app sync cpemon-dev"
Assert-Contains $runbookPath "What This Proves"
Assert-Contains $knowledgePath "CCPU-102: Test GitOps Deployment from Git"
Assert-Contains $interviewPath "Q51: What did CCPU-102 add?"

$helm = Get-Command helm -ErrorAction SilentlyContinue
if ($null -eq $helm) {
    Write-Host "Helm is not available on PATH. Static GitOps validation passed; Helm render validation skipped."
    exit 0
}

& $helm.Source lint $chartPath -f $valuesPath | Out-Host
& $helm.Source template cpemon $chartPath -n cpemon -f $valuesPath | Out-Null

Write-Host "Argo CD GitOps deployment validation passed."
