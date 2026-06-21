$ErrorActionPreference = "Stop"

$files = @(
  "app/cpemon-writer/event_processor.go",
  "app/cpemon-writer/event_processor_test.go",
  "app/cpemon-writer/heartbeat_consumer.go",
  "app/cpemon-writer/wan_status_consumer.go",
  "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md",
  "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
)

foreach ($file in $files) {
  if (-not (Test-Path $file)) {
    throw "Missing required file: $file"
  }
}

$checks = @{
  "processConsumedEvent" = @("app/cpemon-writer/event_processor.go", "app/cpemon-writer/event_processor_test.go")
  "DeviceHeartbeatTopic" = "app/cpemon-writer/event_processor.go"
  "WANStatusTopic" = "app/cpemon-writer/event_processor.go"
  "processHeartbeatConsumedEvent" = @("app/cpemon-writer/event_processor.go", "app/cpemon-writer/heartbeat_consumer.go")
  "processWANStatusConsumedEvent" = @("app/cpemon-writer/event_processor.go", "app/cpemon-writer/wan_status_consumer.go")
  "unsupported consumed event topic" = @("app/cpemon-writer/event_processor.go", "app/cpemon-writer/event_processor_test.go")
}

foreach ($token in $checks.Keys) {
  $matches = Select-String -Path $checks[$token] -Pattern $token -SimpleMatch
  if (-not $matches) {
    throw "Missing required token '$token' in $($checks[$token] -join ', ')"
  }
}

Write-Host "cpemon-writer event processor verification passed."
