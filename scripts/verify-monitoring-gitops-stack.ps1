$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

function Assert-File {
  param([string]$Path)
  if (!(Test-Path $Path)) {
    throw "Expected file does not exist: $Path"
  }
}

function Assert-Contains {
  param(
    [string]$Path,
    [string]$Needle
  )
  $content = Get-Content -Raw $Path
  if ($content -notlike "*$Needle*") {
    throw "Expected '$Needle' in $Path"
  }
}

$applicationPath = Join-Path $root "k8s/gitops/dev/applications/monitoring-dev.yaml"
$valuesPath = Join-Path $root "k8s/monitoring/kube-prometheus-stack-values.yaml"
$runbookPath = Join-Path $root "ops/runbooks/monitoring-observability.md"
$knowledgePath = Join-Path $root "docs/knowledge/monitoring-observability-upgrade.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"

Assert-File $applicationPath
Assert-File $valuesPath
Assert-File $runbookPath
Assert-File $knowledgePath
Assert-File $interviewPath

Assert-Contains $applicationPath "name: monitoring-dev"
Assert-Contains $applicationPath "repoURL: ghcr.io/prometheus-community/charts"
Assert-Contains $applicationPath "chart: kube-prometheus-stack"
Assert-Contains $applicationPath "targetRevision: 86.3.2"
Assert-Contains $applicationPath "releaseName: kps"
Assert-Contains $applicationPath '$values/k8s/monitoring/kube-prometheus-stack-values.yaml'
Assert-Contains $applicationPath "namespace: monitoring"
Assert-Contains $applicationPath "CreateNamespace=false"

Assert-Contains $valuesPath "serviceMonitorSelectorNilUsesHelmValues: false"
Assert-Contains $valuesPath "podMonitorSelectorNilUsesHelmValues: false"
Assert-Contains $valuesPath "ruleSelectorNilUsesHelmValues: false"
Assert-Contains $valuesPath "grafana_dashboard"
Assert-Contains $valuesPath "grafana.local"

Assert-Contains $runbookPath "kube-prometheus-stack"
Assert-Contains $runbookPath "monitoring-dev"
Assert-Contains $knowledgePath "GitOps boundary"
Assert-Contains $interviewPath "Why is monitoring managed as a platform add-on?"

Write-Host "Monitoring GitOps stack verification passed."
