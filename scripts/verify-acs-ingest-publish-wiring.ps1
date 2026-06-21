$ErrorActionPreference = "Stop"

$files = @{
  Main = "app/acs-ingest/main.go"
  MainTest = "app/acs-ingest/main_test.go"
  WANStatus = "app/pkg/events/wan_status.go"
  WANStatusTest = "app/pkg/events/wan_status_test.go"
  Doc = "docs/knowledge/acs-ingest-kafka-producer-refactor.md"
  Interview = "docs/knowledge/interview/story-15-acs-ingest-kafka-producer-refactor.md"
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) {
    throw "Missing expected acs-ingest publish wiring artifact: $path"
  }
}

$mainText = Get-Content $files.Main -Raw
foreach ($snippet in @(
  "KafkaProducerEnabled",
  "NewKafkaProducerFromConfig",
  "handleACSWebhook(c, &cfg, publisher)",
  "publishACSKafkaEvents",
  "NewDeviceHeartbeatEvent",
  "NewWANStatusEvent",
  "kafka_publish_error",
  "ErrWANStatusDataMissing"
)) {
  if ($mainText -notmatch [regex]::Escape($snippet)) {
    throw "acs-ingest publish wiring is missing expected content: $snippet"
  }
}

$testText = Get-Content $files.MainTest -Raw
foreach ($snippet in @(
  "fakeEventPublisher",
  "TestPublishACSKafkaEventsNoopsWhenPublisherDisabled",
  "TestPublishACSKafkaEventsPublishesHeartbeatAndWANStatus",
  "TestPublishACSKafkaEventsSkipsWANStatusWhenPayloadHasNoWANData",
  "TestPublishACSKafkaEventsReturnsPublishError"
)) {
  if ($testText -notmatch [regex]::Escape($snippet)) {
    throw "acs-ingest publish wiring tests are missing expected content: $snippet"
  }
}

$wanStatusText = Get-Content $files.WANStatus -Raw
if ($wanStatusText -notmatch [regex]::Escape("ErrWANStatusDataMissing")) {
  throw "WAN status event mapper is missing ErrWANStatusDataMissing"
}

$wanStatusTestText = Get-Content $files.WANStatusTest -Raw
if ($wanStatusTestText -notmatch [regex]::Escape("errors.Is(err, ErrWANStatusDataMissing)")) {
  throw "WAN status tests do not assert ErrWANStatusDataMissing"
}

$docText = Get-Content $files.Doc -Raw
foreach ($snippet in @(
  "acs-ingest Publish Wiring",
  "KAFKA_PRODUCER_ENABLED",
  "database enqueue succeeds",
  "Missing WAN data is not treated as a publish failure"
)) {
  if ($docText -notmatch [regex]::Escape($snippet)) {
    throw "acs-ingest publish wiring documentation is missing expected content: $snippet"
  }
}

$interviewText = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "CCPU-81",
  "Where does publishing happen in the request flow?",
  "Why publish after the database write?",
  "Why keep the producer behind"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "acs-ingest publish wiring interview notes are missing expected content: $snippet"
  }
}

Write-Host "acs-ingest publish wiring validation passed."
