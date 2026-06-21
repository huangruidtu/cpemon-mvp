$ErrorActionPreference = "Stop"

$files = @{
  Producer = "app/pkg/events/kafka_producer.go"
  ProducerTest = "app/pkg/events/kafka_producer_test.go"
  GoMod = "go.mod"
  GoSum = "go.sum"
  Doc = "docs/knowledge/acs-ingest-kafka-producer-refactor.md"
  Interview = "docs/knowledge/interview/story-15-acs-ingest-kafka-producer-refactor.md"
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) {
    throw "Missing expected Kafka producer artifact: $path"
  }
}

$producerText = Get-Content $files.Producer -Raw
foreach ($snippet in @(
  "github.com/segmentio/kafka-go",
  "type KafkaProducer struct",
  "NewKafkaProducerFromConfig",
  "NewKafkaProducer",
  "NewKafkaProducerWithWriter",
  "func (p *KafkaProducer) Publish",
  "json.Marshal",
  "kafka.Message",
  "func (p *KafkaProducer) Close",
  "parseBootstrapServers"
)) {
  if ($producerText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer implementation is missing expected content: $snippet"
  }
}

$testText = Get-Content $files.ProducerTest -Raw
foreach ($snippet in @(
  "fakeKafkaWriter",
  "TestKafkaProducerPublishesEvent",
  "TestKafkaProducerReturnsWriterError",
  "TestKafkaProducerValidatesTopicAndKey",
  "TestKafkaProducerCloseClosesWriter",
  "TestParseBootstrapServers"
)) {
  if ($testText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer tests are missing expected content: $snippet"
  }
}

$goMod = Get-Content $files.GoMod -Raw
if ($goMod -notmatch [regex]::Escape("github.com/segmentio/kafka-go")) {
  throw "go.mod is missing github.com/segmentio/kafka-go"
}

$docText = Get-Content $files.Doc -Raw
foreach ($snippet in @(
  "Kafka Producer Adapter",
  "segmentio/kafka-go",
  "JSON marshaling",
  "hash balancer",
  "Close()"
)) {
  if ($docText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer documentation is missing expected content: $snippet"
  }
}

$interviewText = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "CCPU-78",
  "Which Go Kafka client did you choose?",
  "Why use a hash balancer?",
  "What remains for later subtasks?"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer interview notes are missing expected content: $snippet"
  }
}

Write-Host "acs-ingest Kafka producer validation passed."

