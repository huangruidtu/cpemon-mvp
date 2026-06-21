$ErrorActionPreference = "Stop"

$schema = "app/pkg/events/wan_status.go"
$test = "app/pkg/events/wan_status_test.go"
$doc = "docs/knowledge/acs-ingest-kafka-producer-refactor.md"
$interview = "docs/knowledge/interview/story-15-acs-ingest-kafka-producer-refactor.md"

foreach ($path in @($schema, $test, $doc, $interview)) {
  if (-not (Test-Path $path)) {
    throw "Missing expected WAN status schema artifact: $path"
  }
}

$schemaText = Get-Content $schema -Raw
$testText = Get-Content $test -Raw
$docText = Get-Content $doc -Raw
$interviewText = Get-Content $interview -Raw

foreach ($snippet in @(
  "WANStatusTopic",
  "cpemon.wan.status.v1",
  "WANStatusSchemaVersion",
  "NewWANStatusEvent",
  "WANStatus",
  "WANIP",
  "SoftwareVersion"
)) {
  if ($schemaText -notmatch [regex]::Escape($snippet)) {
    throw "WAN status schema is missing expected content: $snippet"
  }
}

foreach ($snippet in @(
  "TestNewWANStatusEventMapsIngestEvent",
  "TestNewWANStatusEventDerivesUpStatusFromWANIP",
  "TestNewWANStatusEventRejectsMissingWANData",
  "TestNewWANStatusEventRejectsInvalidJSONPayload",
  "TestWANStatusEventJSONContract"
)) {
  if ($testText -notmatch [regex]::Escape($snippet)) {
    throw "WAN status tests are missing expected content: $snippet"
  }
}

foreach ($snippet in @(
  "WAN Status Event Contract",
  "cpemon.wan.status.v1",
  "wan_status",
  "wan_ip",
  "sw_version"
)) {
  if ($docText -notmatch [regex]::Escape($snippet)) {
    throw "WAN status documentation is missing expected content: $snippet"
  }
}

foreach ($snippet in @(
  "CCPU-80",
  "Why make WAN status a separate event from heartbeat?",
  "stable device identity",
  "raw payload has no WAN data"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "WAN status interview notes are missing expected content: $snippet"
  }
}

Write-Host "acs-ingest WAN status schema validation passed."

