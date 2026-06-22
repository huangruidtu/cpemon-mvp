$ErrorActionPreference = "Stop"

$rule = "k8s/monitoring/cpemon-alerts-prometheusrule.yaml"
$runbook = "ops/runbooks/monitoring-observability.md"
$knowledge = "docs/knowledge/monitoring-observability-upgrade.md"
$interview = "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"

foreach ($path in @($rule, $runbook, $knowledge, $interview)) {
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
  "kind: PrometheusRule",
  "release: kps",
  "CPEmonServiceDown",
  "CPEmonAPIHigh5xxRate",
  "CPEmonAPIHighLatency",
  "CPEmonIngestErrors",
  "CPEmonWriterDeadLetters",
  "CPEmonKafkaMetricsDown",
  "cpemon_api_http_requests_total",
  "cpemon_api_http_request_duration_seconds",
  "acs_webhook_errors_total",
  "cpemon_writer_kafka_deadletters_total",
  "runbook_url"
)) {
  Assert-Contains $rule $snippet
}

Assert-Contains $runbook "Alert baseline"
Assert-Contains $knowledge "CCPU-111 Learning Notes"
Assert-Contains $interview "alerts differ from dashboards"

Write-Host "Prometheus alert baseline verification passed."
