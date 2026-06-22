$ErrorActionPreference = "Stop"

$dashboard = "k8s/monitoring/grafana-dashboard-cpemon-pipeline.yaml"
$runbook = "ops/runbooks/monitoring-observability.md"
$knowledge = "docs/knowledge/monitoring-observability-upgrade.md"
$interview = "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"

foreach ($path in @($dashboard, $runbook, $knowledge, $interview)) {
  if (!(Test-Path $path)) {
    throw "Missing expected file: $path"
  }
}

function Assert-Contains {
  param([string]$Path, [string]$Needle)
  $content = Get-Content -Raw $Path
  if ($content -notlike "*$Needle*") {
    throw "Expected '$Needle' in $Path"
  }
}

foreach ($snippet in @(
  "grafana_dashboard: `"1`"",
  "CPEMon Pipeline Overview",
  "acs_webhook_requests_total",
  "acs_ingest_events_total",
  "cpemon_api_http_requests_total",
  "cpemon_api_http_request_duration_seconds",
  "cpemon_writer_kafka_processing_events_total",
  "cpemon_writer_kafka_deadletters_total",
  'up{namespace=\"kafka\"}'
)) {
  Assert-Contains $dashboard $snippet
}

Assert-Contains $runbook "Pipeline dashboard"
Assert-Contains $knowledge "Grafana pipeline dashboard"
Assert-Contains $interview "dashboard tells the event-flow story"

Write-Host "Grafana pipeline dashboard verification passed."
