$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/cpemon-dev.yaml"
$projectPath = Join-Path $root "k8s/addons/argocd/projects/cpemon-project.yaml"
$chartPath = Join-Path $root "deploy/helm/cpemon/Chart.yaml"
$valuesPath = Join-Path $root "deploy/helm/cpemon/values-dev.yaml"
$runbookPath = Join-Path $root "ops/runbooks/argocd-cpemon-application.md"
$knowledgePath = Join-Path $root "docs/knowledge/argocd-gitops-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-17-argocd-gitops-deployment.md"

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
    if ($content -notlike "*$Needle*") {
        throw "Expected '$Path' to contain '$Needle'"
    }
}

Assert-File $applicationPath
Assert-File $projectPath
Assert-File $chartPath
Assert-File $valuesPath
Assert-File $runbookPath
Assert-File $knowledgePath
Assert-File $interviewPath

Assert-Contains $applicationPath "kind: Application"
Assert-Contains $applicationPath "name: cpemon-dev"
Assert-Contains $applicationPath "namespace: argocd"
Assert-Contains $applicationPath "project: cpemon"
Assert-Contains $applicationPath "repoURL: https://github.com/huangruidtu/cpemon-mvp.git"
Assert-Contains $applicationPath "targetRevision: HEAD"
Assert-Contains $applicationPath "path: deploy/helm/cpemon"
Assert-Contains $applicationPath "releaseName: cpemon"
Assert-Contains $applicationPath "values-dev.yaml"
Assert-Contains $applicationPath "server: https://kubernetes.default.svc"
Assert-Contains $applicationPath "namespace: cpemon"
Assert-Contains $applicationPath "CreateNamespace=false"

Assert-Contains $projectPath "name: cpemon"
Assert-Contains $projectPath "namespace: cpemon"
Assert-Contains $valuesPath "__IMAGE_TAG__"
Assert-Contains $runbookPath "argocd app get cpemon-dev"
Assert-Contains $runbookPath "GitHub Actions -> build and push image"
Assert-Contains $knowledgePath "CCPU-98: Create Application for CPEmon Helm Chart"
Assert-Contains $interviewPath "Q16: What did CCPU-98 add?"

Write-Host "Argo CD CPEmon Application validation passed."
