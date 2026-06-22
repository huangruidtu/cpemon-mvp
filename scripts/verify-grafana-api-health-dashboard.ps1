$ErrorActionPreference = "Stop"

$dashboard = "k8s/monitoring/grafana-dashboard-cpemon-api-health.yaml"
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
  "CPEmon API Health",
  "cpemon_api_http_requests_total",
  "cpemon_api_http_request_duration_seconds",
  "Request Rate by Route and Status",
  "5xx Error Rate by Route",
  "p95 Latency by Route",
  "cpemon-api Service Up"
)) {
  Assert-Contains $dashboard $snippet
}

Assert-Contains $runbook "API health dashboard"
Assert-Contains $knowledge "CCPU-182 Learning Notes"
Assert-Contains $interview "API reliability dashboard"

Write-Host "Grafana API health dashboard verification passed."
