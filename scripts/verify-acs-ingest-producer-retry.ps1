$ErrorActionPreference = "Stop"

$files = @{
  Producer = "app/pkg/events/kafka_producer.go"
  ProducerTest = "app/pkg/events/kafka_producer_test.go"
  Doc = "docs/knowledge/acs-ingest-kafka-producer-refactor.md"
  Interview = "docs/knowledge/interview/story-15-acs-ingest-kafka-producer-refactor.md"
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) {
    throw "Missing expected producer retry artifact: $path"
  }
}

$producerText = Get-Content $files.Producer -Raw
foreach ($snippet in @(
  "type KafkaPublishError struct",
  "PublishErrorInvalidEvent",
  "PublishErrorSerialization",
  "PublishErrorTimeout",
  "PublishErrorWriter",
  "MaxRetries",
  "maxRetries",
  "NewKafkaProducerWithWriterAndRetry",
  "classifyKafkaPublishError",
  "attempts := p.maxRetries + 1"
)) {
  if ($producerText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer retry implementation is missing expected content: $snippet"
  }
}

$testText = Get-Content $files.ProducerTest -Raw
foreach ($snippet in @(
  "TestKafkaProducerRetriesWriterError",
  "TestKafkaProducerReturnsStructuredTimeoutError",
  "TestKafkaProducerFailsFastOnSerializationError",
  "errors.As(err, &publishErr)",
  "writer.attempts"
)) {
  if ($testText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer retry tests are missing expected content: $snippet"
  }
}

$docText = Get-Content $files.Doc -Raw
foreach ($snippet in @(
  "Producer Retry and Error Handling",
  "KafkaPublishError",
  "Fail-fast behavior",
  "Retry behavior",
  "at-least-once",
  "Incident drill"
)) {
  if ($docText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer retry documentation is missing expected content: $snippet"
  }
}

$interviewText = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "CCPU-82",
  "Which errors are fail-fast?",
  "Which errors are retried?",
  "Why is this at-least-once rather than exactly-once?",
  "Why should consumers be idempotent?"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer retry interview notes are missing expected content: $snippet"
  }
}

Write-Host "acs-ingest producer retry validation passed."
