$ErrorActionPreference = "Stop"

$files = @{
  Runbook = "ops/runbooks/acs-ingest-kafka-producer-validation.md"
  Knowledge = "docs/knowledge/acs-ingest-kafka-producer-refactor.md"
  Interview = "docs/knowledge/interview/story-15-acs-ingest-kafka-producer-refactor.md"
  KnowledgeReadme = "docs/knowledge/README.md"
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) {
    throw "Missing expected Kafka producer validation artifact: $path"
  }
}

$runbookText = Get-Content $files.Runbook -Raw
foreach ($snippet in @(
  "ACS webhook payload -> acs-ingest -> EventPublisher -> Kafka topic -> Kafka consumer",
  "KAFKA_PRODUCER_ENABLED=true",
  "cpemon.device.heartbeat.v1",
  "cpemon.wan.status.v1",
  "kafka-console-consumer.sh",
  "Invoke-RestMethod",
  "TEST-CPE-0001",
  "event=kafka_publish result=success",
  "acs_ingest_kafka_producer_publishes_total",
  "Validation Boundary",
  "does not prove live broker connectivity"
)) {
  if ($runbookText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer validation runbook is missing expected content: $snippet"
  }
}

$knowledgeText = Get-Content $files.Knowledge -Raw
foreach ($snippet in @(
  "Integration Validation Path",
  "ops/runbooks/acs-ingest-kafka-producer-validation.md",
  "make acs-ingest-kafka-producer-validation-check",
  "claim live broker proof"
)) {
  if ($knowledgeText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer validation knowledge doc is missing expected content: $snippet"
  }
}

$interviewText = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "CCPU-163",
  "What does the integration runbook prove?",
  "What evidence should you collect?",
  "What is the boundary if no cluster is available?"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer validation interview notes are missing expected content: $snippet"
  }
}

$readmeText = Get-Content $files.KnowledgeReadme -Raw
if ($readmeText -notmatch [regex]::Escape("acs-ingest Kafka Producer Integration Validation Runbook")) {
  throw "Knowledge README does not link the acs-ingest Kafka producer validation runbook"
}

Write-Host "acs-ingest Kafka producer integration validation path passed."
