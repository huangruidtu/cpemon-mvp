$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$chartPath = Join-Path $root "deploy/helm/cpemon"
$valuesPath = Join-Path $root "deploy/helm/cpemon/values-dev.yaml"
$templatePath = Join-Path $root "deploy/helm/cpemon/templates/servicemonitor.yaml"
$renderDir = Join-Path $root "build/helm"
$renderPath = Join-Path $renderDir "cpemon-servicemonitor-rendered.yaml"
$runbookPath = Join-Path $root "ops/runbooks/monitoring-observability.md"
$knowledgePath = Join-Path $root "docs/knowledge/monitoring-observability-upgrade.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"

function Assert-File {
  param([string]$Path)
  if (!(Test-Path $Path)) {
    throw "Missing required file: $Path"
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

Assert-File $valuesPath
Assert-File $templatePath
Assert-File $runbookPath
Assert-File $knowledgePath
Assert-File $interviewPath

Assert-Contains $valuesPath "serviceMonitor:"
Assert-Contains $valuesPath "enabled: true"
Assert-Contains $templatePath "kind: ServiceMonitor"
Assert-Contains $templatePath "release:"
Assert-Contains $templatePath "matchExpressions:"
Assert-Contains $templatePath "port: {{ .Values.defaults.ports.metrics.name"
Assert-Contains $templatePath "path: {{ .Values.serviceMonitor.path"

New-Item -ItemType Directory -Force -Path $renderDir | Out-Null
helm template cpemon $chartPath -n cpemon -f $valuesPath > $renderPath

Assert-Contains $renderPath "kind: ServiceMonitor"
Assert-Contains $renderPath "name: `"cpemon-services`""
Assert-Contains $renderPath "namespace: `"monitoring`""
Assert-Contains $renderPath "release: `"kps`""
Assert-Contains $renderPath "port: `"metrics`""
Assert-Contains $renderPath "path: `"/metrics`""
Assert-Contains $renderPath "interval: `"15s`""
Assert-Contains $renderPath "scrapeTimeout: `"10s`""
Assert-Contains $renderPath "- `"cpemon-api`""
Assert-Contains $renderPath "- `"acs-ingest`""
Assert-Contains $renderPath "- `"cpemon-writer`""

Assert-Contains $runbookPath "Debug Drill: ServiceMonitor Is Not Scraped"
Assert-Contains $knowledgePath "ServiceMonitor"
Assert-Contains $interviewPath "Prometheus Operator contract"

Write-Host "CPEmon ServiceMonitor Helm verification passed."
