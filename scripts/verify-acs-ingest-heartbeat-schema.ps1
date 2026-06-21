$ErrorActionPreference = "Stop"

$schema = "app/pkg/events/heartbeat.go"
$test = "app/pkg/events/heartbeat_test.go"
$doc = "docs/knowledge/acs-ingest-kafka-producer-refactor.md"
$interview = "docs/knowledge/interview/story-15-acs-ingest-kafka-producer-refactor.md"

foreach ($path in @($schema, $test, $doc, $interview)) {
  if (-not (Test-Path $path)) {
    throw "Missing expected heartbeat schema artifact: $path"
  }
}

$schemaText = Get-Content $schema -Raw
$testText = Get-Content $test -Raw
$docText = Get-Content $doc -Raw
$interviewText = Get-Content $interview -Raw

foreach ($snippet in @(
  "DeviceHeartbeatTopic",
  "cpemon.device.heartbeat.v1",
  "DeviceHeartbeatSchemaVersion",
  "NewDeviceHeartbeatEvent",
  "DeviceID",
  "SerialNumber",
  "ReceivedAt"
)) {
  if ($schemaText -notmatch [regex]::Escape($snippet)) {
    throw "Heartbeat schema is missing expected content: $snippet"
  }
}

foreach ($snippet in @(
  "TestNewDeviceHeartbeatEventMapsIngestEvent",
  "TestNewDeviceHeartbeatEventRejectsMissingSerialNumber",
  "TestNewDeviceHeartbeatEventRejectsMissingEventTimestamp",
  "TestDeviceHeartbeatEventJSONContract"
)) {
  if ($testText -notmatch [regex]::Escape($snippet)) {
    throw "Heartbeat schema tests are missing expected content: $snippet"
  }
}

foreach ($snippet in @(
  "Heartbeat Event Contract",
  "message key",
  "event_ts",
  "received_at",
  "normalized CPEmon domain"
)) {
  if ($docText -notmatch [regex]::Escape($snippet)) {
    throw "Heartbeat documentation is missing expected content: $snippet"
  }
}

foreach ($snippet in @(
  "CCPU-79",
  "Why define the event schema before implementing the Kafka producer?",
  "Why not publish the raw ACS webhook payload directly?",
  "stable device identity"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Heartbeat interview notes are missing expected content: $snippet"
  }
}

Write-Host "acs-ingest heartbeat schema validation passed."

