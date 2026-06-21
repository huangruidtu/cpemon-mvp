$ErrorActionPreference = "Stop"

$files = @(
  "app/pkg/events/kafka_consumer.go",
  "app/pkg/events/kafka_consumer_test.go",
  "app/pkg/config/config.go",
  "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md",
  "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
)

foreach ($file in $files) {
  if (-not (Test-Path $file)) {
    throw "Missing required file: $file"
  }
}

$checks = @{
  "CommitMessages" = @("app/pkg/events/kafka_consumer.go", "app/pkg/events/kafka_consumer_test.go")
  "ConsumeErrorCommit" = @("app/pkg/events/kafka_consumer.go", "app/pkg/events/kafka_consumer_test.go")
  "commit_error" = @("app/pkg/events/kafka_consumer.go", "app/pkg/events/kafka_consumer_test.go")
  "KafkaConsumerCommitTimeout" = @("app/pkg/events/kafka_consumer.go", "app/pkg/config/config.go")
  "context.WithoutCancel" = "app/pkg/events/kafka_consumer.go"
  "at-least-once" = @("docs/knowledge/cpemon-writer-kafka-consumer-refactor.md", "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md")
  "only after" = @("docs/knowledge/cpemon-writer-kafka-consumer-refactor.md", "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md")
}

foreach ($token in $checks.Keys) {
  $matches = Select-String -Path $checks[$token] -Pattern $token -SimpleMatch
  if (-not $matches) {
    throw "Missing required token '$token' in $($checks[$token] -join ', ')"
  }
}

Write-Host "cpemon-writer offset commit verification passed."
