$ErrorActionPreference = "Stop"

$files = @(
  "app/cpemon-writer/retry_deadletter.go",
  "app/cpemon-writer/retry_deadletter_test.go",
  "app/cpemon-writer/main.go",
  "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md",
  "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md",
  "ops/runbooks/cpemon-writer-kafka-consumer-lag.md"
)

foreach ($file in $files) {
  if (-not (Test-Path $file)) {
    throw "Missing required file: $file"
  }
}

$checks = @{
  "writerKafkaProcessingCollectors" = @("app/cpemon-writer/retry_deadletter.go", "app/cpemon-writer/retry_deadletter_test.go", "app/cpemon-writer/main.go")
  "cpemon_writer_kafka_processing_events_total" = @("app/cpemon-writer/retry_deadletter.go", "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md")
  "cpemon_writer_kafka_processing_retries_total" = @("app/cpemon-writer/retry_deadletter.go", "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md")
  "cpemon_writer_kafka_deadletters_total" = @("app/cpemon-writer/retry_deadletter.go", "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md")
  "cpemon_writer_kafka_processing_duration_seconds" = @("app/cpemon-writer/retry_deadletter.go", "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md")
  "event=writer_kafka_process" = @("app/cpemon-writer/retry_deadletter.go", "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md")
  "event=writer_kafka_deadletter" = @("app/cpemon-writer/retry_deadletter.go", "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md", "ops/runbooks/cpemon-writer-kafka-consumer-lag.md")
  "result=retry" = "app/cpemon-writer/retry_deadletter.go"
  "duration_ms" = @("app/cpemon-writer/retry_deadletter.go", "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md")
  "high-cardinality" = @("docs/knowledge/cpemon-writer-kafka-consumer-refactor.md", "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md")
}

foreach ($token in $checks.Keys) {
  $matches = Select-String -Path $checks[$token] -Pattern $token -SimpleMatch
  if (-not $matches) {
    throw "Missing required token '$token' in $($checks[$token] -join ', ')"
  }
}

$metricLabelLine = Select-String -Path "app/cpemon-writer/retry_deadletter.go" -Pattern '[]string{"topic", "result", "kind"}' -SimpleMatch
if (-not $metricLabelLine) {
  throw "Processing metrics must use low-cardinality topic/result/kind labels."
}

Write-Host "cpemon-writer processing observability verification passed."
