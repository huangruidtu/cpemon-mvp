$ErrorActionPreference = "Stop"

$files = @{
  ADR = "ADR/cpemon-writer-kafka-consumer-migration.md"
  Runbook = "ops/runbooks/cpemon-writer-kafka-consumer-operations.md"
  Knowledge = "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md"
  Interview = "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
  KnowledgeReadme = "docs/knowledge/README.md"
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) {
    throw "Missing expected writer Kafka consumer operations artifact: $path"
  }
}

$adrText = Get-Content $files.ADR -Raw
foreach ($snippet in @(
  "ADR: cpemon-writer Kafka Consumer Migration",
  "KAFKA_CONSUMER_ENABLED",
  "at-least-once",
  "cpemon.deadletter.v1",
  "Rollback",
  "Out of scope now",
  "ops/runbooks/cpemon-writer-kafka-consumer-operations.md"
)) {
  if ($adrText -notmatch [regex]::Escape($snippet)) {
    throw "Writer Kafka consumer ADR is missing expected content: $snippet"
  }
}

$runbookText = Get-Content $files.Runbook -Raw
foreach ($snippet in @(
  "cpemon-writer Kafka Consumer Operations Runbook",
  "KAFKA_CONSUMER_ENABLED",
  "Enable",
  "Disable / Rollback",
  "No messages processed",
  "Lag grows",
  "Decode failures",
  "DB errors",
  "Duplicate processing",
  "Dead-letter publish errors",
  "make cpemon-writer-kafka-consumer-operations-check"
)) {
  if ($runbookText -notmatch [regex]::Escape($snippet)) {
    throw "Writer Kafka consumer operations runbook is missing expected content: $snippet"
  }
}

$knowledgeText = Get-Content $files.Knowledge -Raw
foreach ($snippet in @(
  "Consumer Operations Runbook And Migration Decision",
  "ADR/cpemon-writer-kafka-consumer-migration.md",
  "ops/runbooks/cpemon-writer-kafka-consumer-operations.md",
  "make cpemon-writer-kafka-consumer-operations-check"
)) {
  if ($knowledgeText -notmatch [regex]::Escape($snippet)) {
    throw "Writer consumer knowledge doc is missing expected operations content: $snippet"
  }
}

$interviewText = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "How would you explain the writer consumer migration decision?",
  "How do you roll it back?",
  "What was intentionally not solved yet?"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Writer consumer interview notes are missing expected operations content: $snippet"
  }
}

$readmeText = Get-Content $files.KnowledgeReadme -Raw
foreach ($snippet in @(
  "cpemon-writer Kafka Consumer Operations Runbook",
  "cpemon-writer Kafka Consumer Migration"
)) {
  if ($readmeText -notmatch [regex]::Escape($snippet)) {
    throw "Knowledge README is missing expected writer consumer operations link: $snippet"
  }
}

Write-Host "cpemon-writer Kafka consumer operations documentation passed."
