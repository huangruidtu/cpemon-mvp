$ErrorActionPreference = "Stop"

$manifest = "k8s/observability/otel-collector.yaml"
$runbook = "ops/runbooks/monitoring-observability.md"
$knowledge = "docs/knowledge/monitoring-observability-upgrade.md"
$interview = "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"

foreach ($path in @($manifest, $runbook, $knowledge, $interview)) {
  if (!(Test-Path $path)) { throw "Missing expected file: $path" }
}

function Assert-Contains {
  param([string]$Path, [string]$Needle)
  $content = Get-Content -Raw $Path
  if ($content -notlike "*$Needle*") { throw "Expected '$Needle' in $Path" }
}

foreach ($snippet in @(
  "kind: ConfigMap",
  "kind: Deployment",
  "kind: Service",
  "name: observability",
  "otlp-grpc",
  "otlp-http",
  "memory_limiter",
  "batch",
  "debug",
  "tempo.observability.svc.cluster.local:4317"
)) { Assert-Contains $manifest $snippet }

Assert-Contains $runbook "OpenTelemetry Collector boundary"
Assert-Contains $knowledge "CCPU-183 Learning Notes"
Assert-Contains $interview "Collector as telemetry pipeline infrastructure"

Write-Host "OpenTelemetry Collector boundary verification passed."
