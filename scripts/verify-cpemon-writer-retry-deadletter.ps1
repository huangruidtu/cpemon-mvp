$ErrorActionPreference = "Stop"

$files = @(
  "app/cpemon-writer/retry_deadletter.go",
  "app/cpemon-writer/retry_deadletter_test.go",
  "app/cpemon-writer/event_processor.go",
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
  "processConsumedEventWithReliability" = @("app/cpemon-writer/retry_deadletter.go", "app/cpemon-writer/retry_deadletter_test.go")
  "deadLetterEvent" = @("app/cpemon-writer/retry_deadletter.go", "app/cpemon-writer/retry_deadletter_test.go")
  "consumer.deadletter" = @("app/cpemon-writer/retry_deadletter.go", "app/cpemon-writer/retry_deadletter_test.go")
  "poison_message" = @("app/cpemon-writer/retry_deadletter.go", "app/cpemon-writer/retry_deadletter_test.go", "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md")
  "retriable_error" = @("app/cpemon-writer/retry_deadletter.go", "app/cpemon-writer/retry_deadletter_test.go")
  "MaxRetries" = @("app/cpemon-writer/retry_deadletter.go", "app/cpemon-writer/retry_deadletter_test.go", "app/pkg/config/config.go")
  "RetryBackoff" = @("app/cpemon-writer/retry_deadletter.go", "app/cpemon-writer/retry_deadletter_test.go", "app/pkg/config/config.go")
  "dead-letter" = @("docs/knowledge/cpemon-writer-kafka-consumer-refactor.md", "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md")
  "infinite retries" = "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
}

foreach ($token in $checks.Keys) {
  $matches = Select-String -Path $checks[$token] -Pattern $token -SimpleMatch
  if (-not $matches) {
    throw "Missing required token '$token' in $($checks[$token] -join ', ')"
  }
}

Write-Host "cpemon-writer retry/dead-letter verification passed."
