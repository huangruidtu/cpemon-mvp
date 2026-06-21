$ErrorActionPreference = "Stop"

$notes = "docs/knowledge/interview/acs-ingest-kafka-producer-learning-notes.md"
$readme = "docs/knowledge/interview/README.md"

foreach ($path in @($notes, $readme)) {
  if (-not (Test-Path $path)) {
    throw "Missing expected Kafka producer learning artifact: $path"
  }
}

$notesText = Get-Content $notes -Raw
foreach ($snippet in @(
  "60-Second Story",
  "Mental Model",
  "Producer",
  "Topic",
  "Partition key",
  "Serialization",
  "Retry",
  "Timeout",
  "At-least-once delivery",
  "Observability",
  "Strong Q&A",
  "Debug Flow",
  "Tradeoffs",
  "Resume Bullet",
  "cpemon.device.heartbeat.v1",
  "cpemon.wan.status.v1",
  "EventPublisher",
  "KAFKA_PRODUCER_ENABLED",
  "idempotent"
)) {
  if ($notesText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer learning notes are missing expected content: $snippet"
  }
}

$readmeText = Get-Content $readme -Raw
foreach ($snippet in @(
  "acs-ingest Kafka Producer Learning Notes",
  "For Story 15",
  "at-least-once delivery"
)) {
  if ($readmeText -notmatch [regex]::Escape($snippet)) {
    throw "Interview README is missing expected Kafka producer learning reference: $snippet"
  }
}

Write-Host "acs-ingest Kafka producer learning notes validation passed."
