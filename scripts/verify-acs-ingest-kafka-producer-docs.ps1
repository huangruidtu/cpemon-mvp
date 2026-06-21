$ErrorActionPreference = "Stop"

$files = @{
  ADR = "ADR/acs-ingest-kafka-producer-migration.md"
  Operations = "ops/runbooks/acs-ingest-kafka-producer-operations.md"
  Knowledge = "docs/knowledge/acs-ingest-kafka-producer-refactor.md"
  Interview = "docs/knowledge/interview/story-15-acs-ingest-kafka-producer-refactor.md"
  Readme = "docs/knowledge/README.md"
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) {
    throw "Missing expected Kafka producer documentation artifact: $path"
  }
}

$adrText = Get-Content $files.ADR -Raw
foreach ($snippet in @(
  "ADR: acs-ingest Kafka Producer Migration",
  "Decision",
  "EventPublisher",
  "KAFKA_PRODUCER_ENABLED",
  "persist before publish",
  "at-least-once",
  "Out of scope now"
)) {
  if ($adrText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer migration ADR is missing expected content: $snippet"
  }
}

$opsText = Get-Content $files.Operations -Raw
foreach ($snippet in @(
  "acs-ingest Kafka Producer Operations Runbook",
  "Kafka unavailable",
  "Topic missing",
  "Serialization failure",
  "Timeout",
  "Bad key or invalid event",
  "Oversized event",
  "network policy",
  "KAFKA_PRODUCER_ENABLED=false"
)) {
  if ($opsText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer operations runbook is missing expected content: $snippet"
  }
}

$knowledgeText = Get-Content $files.Knowledge -Raw
foreach ($snippet in @(
  "Migration Decision And Operations Runbook",
  "ADR/acs-ingest-kafka-producer-migration.md",
  "ops/runbooks/acs-ingest-kafka-producer-operations.md"
)) {
  if ($knowledgeText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer knowledge doc is missing expected content: $snippet"
  }
}

$interviewText = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "CCPU-164",
  "What migration decision was made?",
  "What does the operations runbook cover?",
  "What remains for later stories?"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer interview docs are missing expected content: $snippet"
  }
}

$readmeText = Get-Content $files.Readme -Raw
foreach ($snippet in @(
  "acs-ingest Kafka Producer Migration Decision",
  "acs-ingest Kafka Producer Operations Runbook"
)) {
  if ($readmeText -notmatch [regex]::Escape($snippet)) {
    throw "Knowledge README is missing expected link: $snippet"
  }
}

Write-Host "acs-ingest Kafka producer docs validation passed."
