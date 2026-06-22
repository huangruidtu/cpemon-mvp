$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/monitoring-dev.yaml"
$projectPath = Join-Path $root "k8s/addons/argocd/projects/cpemon-project.yaml"
$valuesPath = Join-Path $root "k8s/monitoring/kube-prometheus-stack-values.yaml"
$runbookPath = Join-Path $root "ops/runbooks/argocd-monitoring-application.md"
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
Assert-File $valuesPath
Assert-File $runbookPath
Assert-File $knowledgePath
Assert-File $interviewPath

Assert-Contains $applicationPath "kind: Application"
Assert-Contains $applicationPath "name: monitoring-dev"
Assert-Contains $applicationPath "namespace: argocd"
Assert-Contains $applicationPath "project: cpemon"
Assert-Contains $applicationPath "sources:"
Assert-Contains $applicationPath "repoURL: ghcr.io/prometheus-community/charts"
Assert-Contains $applicationPath "chart: kube-prometheus-stack"
Assert-Contains $applicationPath "targetRevision: 86.3.2"
Assert-Contains $applicationPath "releaseName: kps"
Assert-Contains $applicationPath '$values/k8s/monitoring/kube-prometheus-stack-values.yaml'
Assert-Contains $applicationPath "repoURL: https://github.com/huangruidtu/cpemon-mvp.git"
Assert-Contains $applicationPath "ref: values"
Assert-Contains $applicationPath "server: https://kubernetes.default.svc"
Assert-Contains $applicationPath "namespace: monitoring"
Assert-Contains $applicationPath "CreateNamespace=false"

Assert-Contains $projectPath "ghcr.io/prometheus-community/charts"
Assert-Contains $projectPath "namespace: monitoring"
Assert-Contains $valuesPath "grafana:"
Assert-Contains $valuesPath "prometheus:"
Assert-Contains $runbookPath "argocd app get monitoring-dev"
Assert-Contains $runbookPath "ServiceMonitor"
Assert-Contains $knowledgePath "CCPU-100: Create Application for Monitoring Stack"
Assert-Contains $interviewPath "Q26: What did CCPU-100 add?"

Write-Host "Argo CD Monitoring Application validation passed."
