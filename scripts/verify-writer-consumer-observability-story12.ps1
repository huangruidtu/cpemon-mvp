$ErrorActionPreference = "Stop"

$files = @{
  Consumer = "app/pkg/events/kafka_consumer.go"
  Processing = "app/cpemon-writer/retry_deadletter.go"
  Main = "app/cpemon-writer/main.go"
  Knowledge = "docs/knowledge/monitoring-observability-upgrade.md"
  Runbook = "ops/runbooks/monitoring-observability.md"
  Interview = "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"
}

foreach ($path in $files.Values) {
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
  "cpemon_writer_kafka_consumer_last_consumed_offset",
  "cpemon_writer_kafka_consumer_last_committed_offset",
  "cpemon_writer_kafka_consumer_message_age_seconds",
  "cpemon_writer_kafka_consumer_reader_lag_messages",
  "KafkaConsumerCollectors"
)) {
  Assert-Contains $files.Consumer $snippet
}

foreach ($snippet in @(
  "cpemon_writer_kafka_processing_events_total",
  "cpemon_writer_kafka_processing_retries_total",
  "cpemon_writer_kafka_deadletters_total",
  "cpemon_writer_kafka_processing_duration_seconds",
  "writerKafkaProcessingCollectors"
)) {
  Assert-Contains $files.Processing $snippet
}

Assert-Contains $files.Main "appevents.KafkaConsumerCollectors()"
Assert-Contains $files.Main "writerKafkaProcessingCollectors()"

foreach ($snippet in @(
  "Writer Consumer Metrics",
  "consumer lag",
  "at-least-once",
  "dead-letter"
)) {
  Assert-Contains $files.Knowledge $snippet
}

foreach ($snippet in @(
  "at-least-once",
  "consumed offset",
  "committed offset",
  "dead-letter"
)) {
  Assert-Contains $files.Interview $snippet
}

Assert-Contains $files.Runbook "cpemon_writer_kafka_consumer_last_consumed_offset"
Assert-Contains $files.Runbook "cpemon_writer_kafka_processing_events_total"

Write-Host "Writer consumer observability verification passed."
