$ErrorActionPreference = "Stop"

$files = @{
  HeartbeatTest = "app/pkg/events/heartbeat_test.go"
  WANStatusTest = "app/pkg/events/wan_status_test.go"
  PublisherTest = "app/pkg/events/publisher_test.go"
  ProducerTest = "app/pkg/events/kafka_producer_test.go"
  IngestTest = "app/acs-ingest/main_test.go"
  Doc = "docs/knowledge/acs-ingest-kafka-producer-refactor.md"
  Interview = "docs/knowledge/interview/story-15-acs-ingest-kafka-producer-refactor.md"
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) {
    throw "Missing expected unit-test artifact: $path"
  }
}

$heartbeatText = Get-Content $files.HeartbeatTest -Raw
foreach ($snippet in @(
  "TestNewDeviceHeartbeatEventMapsIngestEvent",
  "TestDeviceHeartbeatEventJSONContract"
)) {
  if ($heartbeatText -notmatch [regex]::Escape($snippet)) {
    throw "Heartbeat unit tests are missing expected content: $snippet"
  }
}

$wanText = Get-Content $files.WANStatusTest -Raw
foreach ($snippet in @(
  "TestNewWANStatusEventMapsIngestEvent",
  "TestNewWANStatusEventDerivesUpStatusFromWANIP",
  "TestNewWANStatusEventRejectsMissingWANData",
  "TestNewWANStatusEventRejectsInvalidJSONPayload",
  "TestWANStatusEventJSONContract"
)) {
  if ($wanText -notmatch [regex]::Escape($snippet)) {
    throw "WAN status unit tests are missing expected content: $snippet"
  }
}

$publisherText = Get-Content $files.PublisherTest -Raw
foreach ($snippet in @(
  "TestHeartbeatAndWANStatusEventsArePublishable",
  "TestEventPublisherCanUseFakeWithoutKafka"
)) {
  if ($publisherText -notmatch [regex]::Escape($snippet)) {
    throw "EventPublisher unit tests are missing expected content: $snippet"
  }
}

$producerText = Get-Content $files.ProducerTest -Raw
foreach ($snippet in @(
  "TestKafkaProducerPublishesEvent",
  "TestKafkaProducerRetriesWriterError",
  "TestKafkaProducerReturnsStructuredTimeoutError",
  "TestKafkaProducerFailsFastOnSerializationError",
  "TestKafkaProducerCollectorsAreExposed"
)) {
  if ($producerText -notmatch [regex]::Escape($snippet)) {
    throw "Kafka producer unit tests are missing expected content: $snippet"
  }
}

$ingestText = Get-Content $files.IngestTest -Raw
foreach ($snippet in @(
  "TestPublishACSKafkaEventsNoopsWhenPublisherDisabled",
  "TestPublishACSKafkaEventsPublishesHeartbeatAndWANStatus",
  "TestPublishACSKafkaEventsSkipsWANStatusWhenPayloadHasNoWANData",
  "TestPublishACSKafkaEventsReturnsWANBuildError",
  "TestPublishACSKafkaEventsReturnsPublishError"
)) {
  if ($ingestText -notmatch [regex]::Escape($snippet)) {
    throw "acs-ingest publish unit tests are missing expected content: $snippet"
  }
}

$docText = Get-Content $files.Doc -Raw
foreach ($snippet in @(
  "Unit Test Boundary",
  "Unit tests cover",
  "Unit tests intentionally do not prove",
  "go test ./...",
  "integration validation"
)) {
  if ($docText -notmatch [regex]::Escape($snippet)) {
    throw "Unit-test documentation is missing expected content: $snippet"
  }
}

$interviewText = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "CCPU-84",
  "What do the unit tests prove?",
  "Why keep unit tests broker-free?",
  "What do unit tests not prove?",
  "testing-pyramid"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Unit-test interview notes are missing expected content: $snippet"
  }
}

Write-Host "acs-ingest unit-test boundary validation passed."
