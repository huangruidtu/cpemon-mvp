$ErrorActionPreference = "Stop"

$files = @(
  "app/pkg/events/consumer_test.go",
  "app/pkg/events/kafka_consumer_test.go",
  "app/cpemon-writer/event_processor_test.go",
  "app/cpemon-writer/heartbeat_consumer_test.go",
  "app/cpemon-writer/wan_status_consumer_test.go",
  "app/cpemon-writer/retry_deadletter_test.go",
  "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md",
  "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
)

foreach ($file in $files) {
  if (-not (Test-Path $file)) {
    throw "Missing required file: $file"
  }
}

$checks = @{
  "TestEventConsumerCanUseFakeWithoutKafka" = "app/pkg/events/consumer_test.go"
  "TestKafkaConsumerConsumesMessageThroughBoundary" = "app/pkg/events/kafka_consumer_test.go"
  "TestKafkaConsumerReturnsCommitErrorWithMessageContext" = "app/pkg/events/kafka_consumer_test.go"
  "TestProcessConsumedEventRoutesHeartbeatToMySQLWrites" = "app/cpemon-writer/event_processor_test.go"
  "TestProcessConsumedEventRoutesWANStatusToMySQLWrites" = "app/cpemon-writer/event_processor_test.go"
  "TestDecodeHeartbeatWriteRejectsInvalidPayload" = "app/cpemon-writer/heartbeat_consumer_test.go"
  "TestDecodeWANStatusWriteRejectsInvalidPayload" = "app/cpemon-writer/wan_status_consumer_test.go"
  "TestProcessConsumedEventWithReliabilityRetriesRetriableError" = "app/cpemon-writer/retry_deadletter_test.go"
  "TestProcessConsumedEventWithReliabilityStopsWhenRetrySleepContextCancels" = "app/cpemon-writer/retry_deadletter_test.go"
  "TestDeadLetterEventUsesOffsetKeyWhenMessageKeyIsMissing" = "app/cpemon-writer/retry_deadletter_test.go"
  "Consumer Unit Test Matrix" = "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md"
  "broker-free" = @("docs/knowledge/cpemon-writer-kafka-consumer-refactor.md", "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md")
}

foreach ($token in $checks.Keys) {
  $matches = Select-String -Path $checks[$token] -Pattern $token -SimpleMatch
  if (-not $matches) {
    throw "Missing required token '$token' in $($checks[$token] -join ', ')"
  }
}

Write-Host "cpemon-writer consumer unit test verification passed."
