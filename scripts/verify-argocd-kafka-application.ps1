$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/kafka-dev.yaml"
$projectPath = Join-Path $root "k8s/addons/argocd/projects/cpemon-project.yaml"
$valuesPath = Join-Path $root "k8s/addons/kafka/values.yaml"
$runbookPath = Join-Path $root "ops/runbooks/argocd-kafka-application.md"
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
Assert-Contains $applicationPath "name: kafka-dev"
Assert-Contains $applicationPath "namespace: argocd"
Assert-Contains $applicationPath "project: cpemon"
Assert-Contains $applicationPath "sources:"
Assert-Contains $applicationPath "repoURL: registry-1.docker.io/bitnamicharts"
Assert-Contains $applicationPath "chart: kafka"
Assert-Contains $applicationPath "targetRevision: 32.4.3"
Assert-Contains $applicationPath "releaseName: kafka"
Assert-Contains $applicationPath '$values/k8s/addons/kafka/values.yaml'
Assert-Contains $applicationPath "repoURL: https://github.com/huangruidtu/cpemon-mvp.git"
Assert-Contains $applicationPath "ref: values"
Assert-Contains $applicationPath "server: https://kubernetes.default.svc"
Assert-Contains $applicationPath "namespace: kafka"
Assert-Contains $applicationPath "CreateNamespace=false"

Assert-Contains $projectPath "registry-1.docker.io/bitnamicharts"
Assert-Contains $projectPath "namespace: kafka"
Assert-Contains $valuesPath "cpemon.device.heartbeat.v1"
Assert-Contains $valuesPath "cpemon.wan.status.v1"
Assert-Contains $runbookPath "argocd app get kafka-dev"
Assert-Contains $runbookPath "helm template kafka oci://registry-1.docker.io/bitnamicharts/kafka"
Assert-Contains $knowledgePath "CCPU-99: Create Application for Kafka"
Assert-Contains $interviewPath "Q21: What did CCPU-99 add?"

Write-Host "Argo CD Kafka Application validation passed."
