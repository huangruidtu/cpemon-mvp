$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/argo-rollouts-dev.yaml"
$projectPath = Join-Path $root "k8s/addons/argocd/projects/cpemon-project.yaml"
$namespacePath = Join-Path $root "k8s/base/namespaces.yaml"
$valuesPath = Join-Path $root "k8s/addons/argo-rollouts/values.yaml"
$applicationsReadmePath = Join-Path $root "k8s/gitops/dev/applications/README.md"
$runbookPath = Join-Path $root "ops/runbooks/argo-rollouts-controller.md"
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
    if ($content -notlike "*$Needle*") {
        throw "Expected '$Path' to contain '$Needle'"
    }
}

Assert-File $applicationPath
Assert-File $projectPath
Assert-File $namespacePath
Assert-File $valuesPath
Assert-File $applicationsReadmePath
Assert-File $runbookPath
Assert-File $knowledgePath
Assert-File $interviewPath

Assert-Contains $applicationPath "kind: Application"
Assert-Contains $applicationPath "name: argo-rollouts-dev"
Assert-Contains $applicationPath "namespace: argocd"
Assert-Contains $applicationPath "project: cpemon"
Assert-Contains $applicationPath "repoURL: https://argoproj.github.io/argo-helm"
Assert-Contains $applicationPath "chart: argo-rollouts"
Assert-Contains $applicationPath "targetRevision: 2.41.0"
Assert-Contains $applicationPath "releaseName: argo-rollouts"
Assert-Contains $applicationPath '$values/k8s/addons/argo-rollouts/values.yaml'
Assert-Contains $applicationPath "namespace: argo-rollouts"
Assert-Contains $applicationPath "CreateNamespace=false"

Assert-Contains $projectPath "https://argoproj.github.io/argo-helm"
Assert-Contains $projectPath "namespace: argo-rollouts"
Assert-Contains $namespacePath "name: argo-rollouts"
Assert-Contains $namespacePath "cpemon.io/layer: progressive-delivery"
Assert-Contains $valuesPath "installCRDs: true"
Assert-Contains $valuesPath "keepCRDs: true"
Assert-Contains $valuesPath "replicas: 2"
Assert-Contains $valuesPath "enabled: false"
Assert-Contains $applicationsReadmePath "argo-rollouts-dev"
Assert-Contains $runbookPath "kubectl get pods,deploy,svc -n argo-rollouts"
Assert-Contains $runbookPath "platform delivery infrastructure"
Assert-Contains $knowledgePath "CCPU-114: Install Argo Rollouts Controller"
Assert-Contains $knowledgePath "controller is shared infrastructure"
Assert-Contains $interviewPath "Q1: Why is Argo Rollouts platform delivery infrastructure?"
Assert-Contains $interviewPath "Q3: What did CCPU-114 add?"

Write-Host "Argo Rollouts controller boundary validation passed."
