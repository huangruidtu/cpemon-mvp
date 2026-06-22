$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$valuesPath = Join-Path $root "k8s/addons/kafka/values.yaml"
$runbookPath = Join-Path $root "ops/runbooks/monitoring-observability.md"
$knowledgePath = Join-Path $root "docs/knowledge/monitoring-observability-upgrade.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"
$renderDir = Join-Path $root "build/helm"
$renderPath = Join-Path $renderDir "kafka-metrics-rendered.yaml"

foreach ($path in @($valuesPath, $runbookPath, $knowledgePath, $interviewPath)) {
  if (!(Test-Path $path)) {
    throw "Missing expected file: $path"
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

Assert-Contains $valuesPath "metrics:"
Assert-Contains $valuesPath "jmx:"
Assert-Contains $valuesPath "enabled: true"
Assert-Contains $valuesPath "serviceMonitor:"
Assert-Contains $valuesPath "namespace: monitoring"
Assert-Contains $valuesPath "release: kps"
Assert-Contains $valuesPath "interval: 30s"
Assert-Contains $valuesPath "scrapeTimeout: 10s"

New-Item -ItemType Directory -Force -Path $renderDir | Out-Null
helm template kafka oci://registry-1.docker.io/bitnamicharts/kafka `
  --namespace kafka `
  --version 32.4.3 `
  --values $valuesPath > $renderPath

Assert-Contains $renderPath "kind: ServiceMonitor"
Assert-Contains $renderPath 'namespace: "monitoring"'
Assert-Contains $renderPath "release: kps"
Assert-Contains $renderPath "jmx-exporter"
Assert-Contains $renderPath "5556"

Assert-Contains $runbookPath "Kafka Metrics Boundary"
Assert-Contains $knowledgePath "broker metrics"
Assert-Contains $interviewPath "broker metrics versus application metrics"

Write-Host "Kafka metrics boundary verification passed."
