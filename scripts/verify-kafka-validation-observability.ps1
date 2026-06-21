$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbook = Join-Path $root "ops/runbooks/kafka-validation-observability.md"

if (-not (Test-Path $runbook)) {
  throw "Missing Kafka validation and observability runbook."
}

$content = Get-Content $runbook -Raw
$requiredSnippets = @(
  "CCPU-160",
  "Repository validation",
  "Live validation",
  "make kafka-namespace-check",
  "make kafka-helm-workflow-check",
  "make kafka-topics-check",
  "make kafka-config-check",
  "kafka.kafka.svc.cluster.local:9092",
  "consumer group lag",
  "ServiceMonitor Boundary",
  "Failure Triage",
  "Interview Summary"
)

foreach ($snippet in $requiredSnippets) {
  if ($content -notmatch [regex]::Escape($snippet)) {
    throw "Kafka validation/observability runbook is missing expected content: $snippet"
  }
}

Write-Host "Kafka validation and observability runbook validation passed."
