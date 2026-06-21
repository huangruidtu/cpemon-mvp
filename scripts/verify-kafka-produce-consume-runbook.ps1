$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbook = Join-Path $root "ops/runbooks/kafka-produce-consume-validation.md"

if (-not (Test-Path $runbook)) {
  throw "Missing Kafka produce/consume validation runbook."
}

$content = Get-Content $runbook -Raw
$requiredSnippets = @(
  "CCPU-74",
  "kafka-console-producer.sh",
  "kafka-console-consumer.sh",
  "cpemon.device.heartbeat.v1",
  "kafka.kafka.svc.cluster.local:9092",
  "TEST-CPE-0001",
  "manual-kafka-validation",
  "kubectl exec",
  "platform-level Kafka connectivity",
  "does not validate CPEmon application producer code"
)

foreach ($snippet in $requiredSnippets) {
  if ($content -notmatch [regex]::Escape($snippet)) {
    throw "Kafka produce/consume runbook is missing expected content: $snippet"
  }
}

Write-Host "Kafka produce/consume runbook validation passed."
