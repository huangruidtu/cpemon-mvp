$ErrorActionPreference = "Stop"

$publisher = "app/pkg/events/publisher.go"
$test = "app/pkg/events/publisher_test.go"
$doc = "docs/knowledge/acs-ingest-kafka-producer-refactor.md"
$interview = "docs/knowledge/interview/story-15-acs-ingest-kafka-producer-refactor.md"

foreach ($path in @($publisher, $test, $doc, $interview)) {
  if (-not (Test-Path $path)) {
    throw "Missing expected EventPublisher artifact: $path"
  }
}

$publisherText = Get-Content $publisher -Raw
$testText = Get-Content $test -Raw
$docText = Get-Content $doc -Raw
$interviewText = Get-Content $interview -Raw

foreach ($snippet in @(
  "type PublishableEvent interface",
  "Topic() string",
  "Key() string",
  "type EventPublisher interface",
  "Publish(ctx context.Context, event PublishableEvent) error"
)) {
  if ($publisherText -notmatch [regex]::Escape($snippet)) {
    throw "EventPublisher interface is missing expected content: $snippet"
  }
}

foreach ($snippet in @(
  "recordingPublisher",
  "TestHeartbeatAndWANStatusEventsArePublishable",
  "TestEventPublisherCanUseFakeWithoutKafka",
  "TestEventPublisherPropagatesContextCancellation"
)) {
  if ($testText -notmatch [regex]::Escape($snippet)) {
    throw "EventPublisher tests are missing expected content: $snippet"
  }
}

foreach ($snippet in @(
  "EventPublisher Boundary",
  "dependency-inversion",
  "context.Context",
  "Tests can use a fake publisher without Kafka"
)) {
  if ($docText -notmatch [regex]::Escape($snippet)) {
    throw "EventPublisher documentation is missing expected content: $snippet"
  }
}

foreach ($snippet in @(
  "CCPU-77",
  "Why introduce",
  "How does this help testing?",
  "concrete adapter responsibilities"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "EventPublisher interview notes are missing expected content: $snippet"
  }
}

Write-Host "acs-ingest EventPublisher validation passed."
