$ErrorActionPreference = "Stop"

$files = @(
  "app/pkg/events/kafka_consumer.go",
  "app/pkg/events/kafka_consumer_test.go",
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
  "KafkaConsumerCollectors" = @("app/pkg/events/kafka_consumer.go", "app/pkg/events/kafka_consumer_test.go", "app/cpemon-writer/main.go")
  "cpemon_writer_kafka_consumer_last_consumed_offset" = @("app/pkg/events/kafka_consumer.go", "ops/runbooks/cpemon-writer-kafka-consumer-lag.md")
  "cpemon_writer_kafka_consumer_last_committed_offset" = @("app/pkg/events/kafka_consumer.go", "ops/runbooks/cpemon-writer-kafka-consumer-lag.md")
  "cpemon_writer_kafka_consumer_message_age_seconds" = @("app/pkg/events/kafka_consumer.go", "ops/runbooks/cpemon-writer-kafka-consumer-lag.md")
  "cpemon_writer_kafka_consumer_reader_lag_messages" = @("app/pkg/events/kafka_consumer.go", "ops/runbooks/cpemon-writer-kafka-consumer-lag.md")
  "group" = "app/pkg/events/kafka_consumer.go"
  "topic" = "app/pkg/events/kafka_consumer.go"
  "partition" = "app/pkg/events/kafka_consumer.go"
  "kafka-consumer-groups.sh" = "ops/runbooks/cpemon-writer-kafka-consumer-lag.md"
  "high-cardinality" = @("docs/knowledge/cpemon-writer-kafka-consumer-refactor.md", "ops/runbooks/cpemon-writer-kafka-consumer-lag.md")
}

foreach ($token in $checks.Keys) {
  $matches = Select-String -Path $checks[$token] -Pattern $token -SimpleMatch
  if (-not $matches) {
    throw "Missing required token '$token' in $($checks[$token] -join ', ')"
  }
}

Write-Host "cpemon-writer consumer lag verification passed."
