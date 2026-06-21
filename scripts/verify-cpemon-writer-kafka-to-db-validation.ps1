$ErrorActionPreference = "Stop"

$files = @{
  Runbook = "ops/runbooks/cpemon-writer-kafka-to-db-validation.md"
  Main = "app/cpemon-writer/main.go"
  Knowledge = "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md"
  Interview = "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
  KnowledgeReadme = "docs/knowledge/README.md"
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) {
    throw "Missing expected Kafka-to-DB validation artifact: $path"
  }
}

$runbookText = Get-Content $files.Runbook -Raw
foreach ($snippet in @(
  "Kafka topic -> cpemon-writer Kafka consumer -> MySQL",
  "KAFKA_CONSUMER_ENABLED=true",
  "cpemon.device.heartbeat.v1",
  "cpemon.wan.status.v1",
  "cpemon.deadletter.v1",
  "kafka-console-producer.sh",
  "TEST-CPE-KAFKA-DB-001",
  "SELECT sn, last_seen, wan_ip, sw_version",
  "kafka-consumer-groups.sh",
  "cpemon_writer_kafka_processing_events_total",
  "Validation Boundary",
  "does not prove live broker-to-DB behavior"
)) {
  if ($runbookText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka-to-DB validation runbook is missing expected content: $snippet"
  }
}

$mainText = Get-Content $files.Main -Raw
foreach ($snippet in @(
  "KafkaConsumerEnabled",
  "startKafkaConsumerRuntime",
  "NewKafkaConsumerFromConfig",
  "NewKafkaProducerFromConfig",
  "processConsumedEventWithReliability",
  "event=writer_kafka_consumer result=start"
)) {
  if ($mainText -notmatch [regex]::Escape($snippet)) {
    throw "cpemon-writer main wiring is missing expected content: $snippet"
  }
}

$knowledgeText = Get-Content $files.Knowledge -Raw
foreach ($snippet in @(
  "Kafka-to-DB Integration Validation",
  "ops/runbooks/cpemon-writer-kafka-to-db-validation.md",
  "make cpemon-writer-kafka-to-db-validation-check",
  "does not prove live broker-to-DB behavior"
)) {
  if ($knowledgeText -notmatch [regex]::Escape($snippet)) {
    throw "Writer consumer knowledge doc is missing expected validation content: $snippet"
  }
}

$interviewText = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "How do you prove Kafka-to-DB integration?",
  "What is the boundary if no live cluster is available?",
  "broker-to-DB"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Writer consumer interview notes are missing expected validation content: $snippet"
  }
}

$readmeText = Get-Content $files.KnowledgeReadme -Raw
if ($readmeText -notmatch [regex]::Escape("cpemon-writer Kafka-to-DB Integration Validation")) {
  throw "Knowledge README does not link the cpemon-writer Kafka-to-DB validation runbook"
}

Write-Host "cpemon-writer Kafka-to-DB integration validation path passed."
