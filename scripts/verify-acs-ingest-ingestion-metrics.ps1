$ErrorActionPreference = "Stop"

$files = @{
  Main = "app/acs-ingest/main.go"
  Test = "app/acs-ingest/main_test.go"
  Runbook = "ops/runbooks/monitoring-observability.md"
  Knowledge = "docs/knowledge/monitoring-observability-upgrade.md"
  Interview = "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"
}

foreach ($path in $files.Values) {
  if (!(Test-Path $path)) {
    throw "Missing expected file: $path"
  }
}

$main = Get-Content $files.Main -Raw
foreach ($snippet in @(
  "acs_webhook_requests_total",
  "acs_webhook_errors_total",
  "acs_webhook_duration_seconds",
  "acs_webhook_payload_bytes",
  "acs_ingest_events_total",
  "acsIngestCollectors",
  "recordWebhookOutcome",
  "queued",
  "invalid",
  "db_failed",
  "publish_failed"
)) {
  if ($main -notlike "*$snippet*") {
    throw "acs-ingest metric implementation is missing: $snippet"
  }
}

$test = Get-Content $files.Test -Raw
if ($test -notlike "*TestACSIngestCollectorsAreExposed*") {
  throw "acs-ingest tests do not cover collector exposure"
}

$knowledge = Get-Content $files.Knowledge -Raw
$runbook = Get-Content $files.Runbook -Raw
$interview = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "acs_webhook_duration_seconds",
  "acs_webhook_payload_bytes",
  "acs_ingest_events_total",
  "low-cardinality"
)) {
  if ($knowledge -notlike "*$snippet*" -and $runbook -notlike "*$snippet*" -and $interview -notlike "*$snippet*") {
    throw "documentation is missing metric concept: $snippet"
  }
}

Write-Host "acs-ingest ingestion metrics verification passed."
