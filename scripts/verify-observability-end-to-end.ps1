$ErrorActionPreference = "Stop"

$checks = @(
  "scripts/verify-monitoring-gitops-stack.ps1",
  "scripts/verify-cpemon-servicemonitor-helm.ps1",
  "scripts/verify-acs-ingest-ingestion-metrics.ps1",
  "scripts/verify-kafka-metrics-boundary.ps1",
  "scripts/verify-writer-consumer-observability-story12.ps1",
  "scripts/verify-cpemon-api-http-metrics.ps1",
  "scripts/verify-grafana-pipeline-dashboard.ps1",
  "scripts/verify-grafana-api-health-dashboard.ps1",
  "scripts/verify-prometheus-alert-baseline.ps1",
  "scripts/verify-otel-collector-boundary.ps1",
  "scripts/verify-minimal-tracing.ps1",
  "scripts/verify-trace-id-structured-logs.ps1",
  "scripts/verify-trace-export-boundary.ps1"
)

foreach ($check in $checks) {
  if (-not (Test-Path $check)) {
    throw "Missing observability validation script: $check"
  }

  Write-Host "Running $check"
  & powershell -ExecutionPolicy Bypass -File $check
}

$docs = @(
  "ops/runbooks/monitoring-observability.md",
  "docs/knowledge/monitoring-observability-upgrade.md",
  "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"
)

foreach ($doc in $docs) {
  $content = Get-Content -Raw $doc
  foreach ($needle in @("End-to-end validation", "Repository proof", "Live cluster proof")) {
    if (-not $content.Contains($needle)) {
      throw "$doc does not contain expected validation language: $needle"
    }
  }
}

Write-Host "observability end-to-end validation checks passed"
