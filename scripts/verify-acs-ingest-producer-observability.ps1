$ErrorActionPreference = "Stop"

$files = @{
  Main = "app/acs-ingest/main.go"
  Producer = "app/pkg/events/kafka_producer.go"
  ProducerTest = "app/pkg/events/kafka_producer_test.go"
  Doc = "docs/knowledge/acs-ingest-kafka-producer-refactor.md"
  Interview = "docs/knowledge/interview/story-15-acs-ingest-kafka-producer-refactor.md"
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) {
    throw "Missing expected producer observability artifact: $path"
  }
}

$mainText = Get-Content $files.Main -Raw
if ($mainText -notmatch [regex]::Escape("events.KafkaProducerCollectors()")) {
  throw "acs-ingest main does not register Kafka producer collectors"
}

$producerText = Get-Content $files.Producer -Raw
foreach ($snippet in @(
  "acs_ingest_kafka_producer_publishes_total",
  "acs_ingest_kafka_producer_publish_errors_total",
  "acs_ingest_kafka_producer_publish_duration_seconds",
  "KafkaProducerCollectors",
  "recordKafkaPublishSuccess",
  "recordKafkaPublishFailure",
  "event=kafka_publish",
  "duration_ms",
  "topic",
  "key",
  "attempts"
)) {
  if ($producerText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer observability implementation is missing expected content: $snippet"
  }
}

$testText = Get-Content $files.ProducerTest -Raw
if ($testText -notmatch [regex]::Escape("TestKafkaProducerCollectorsAreExposed")) {
  throw "Kafka producer tests do not cover collector exposure"
}

$docText = Get-Content $files.Doc -Raw
foreach ($snippet in @(
  "Producer Metrics and Structured Logging",
  "acs_ingest_kafka_producer_publishes_total",
  "acs_ingest_kafka_producer_publish_errors_total",
  "acs_ingest_kafka_producer_publish_duration_seconds",
  "Metrics avoid the message key as a label",
  "Logs do not dump full event payloads"
)) {
  if ($docText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer observability documentation is missing expected content: $snippet"
  }
}

$interviewText = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "CCPU-83",
  "Which metrics were added?",
  "Why not put the device key in Prometheus labels?",
  "How would you debug a publish incident?"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer observability interview notes are missing expected content: $snippet"
  }
}

Write-Host "acs-ingest producer observability validation passed."
