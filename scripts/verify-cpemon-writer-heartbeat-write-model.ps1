$ErrorActionPreference = "Stop"

$files = @(
  "app/cpemon-writer/heartbeat_consumer.go",
  "app/cpemon-writer/heartbeat_consumer_test.go",
  "app/pkg/events/heartbeat.go",
  "sql/schema.sql",
  "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md",
  "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
)

foreach ($file in $files) {
  if (-not (Test-Path $file)) {
    throw "Missing required file: $file"
  }
}

$checks = @{
  "decodeHeartbeatWrite" = @("app/cpemon-writer/heartbeat_consumer.go", "app/cpemon-writer/heartbeat_consumer_test.go")
  "processHeartbeatConsumedEvent" = @("app/cpemon-writer/heartbeat_consumer.go", "app/cpemon-writer/heartbeat_consumer_test.go")
  "writeHeartbeatStatus" = @("app/cpemon-writer/heartbeat_consumer.go", "app/cpemon-writer/heartbeat_consumer_test.go")
  "DeviceHeartbeatEvent" = @("app/cpemon-writer/heartbeat_consumer.go", "app/pkg/events/heartbeat.go")
  "INSERT INTO cpe_status" = "app/cpemon-writer/heartbeat_consumer.go"
  "INSERT INTO cpe_status_history" = "app/cpemon-writer/heartbeat_consumer.go"
  "ON DUPLICATE KEY UPDATE" = "app/cpemon-writer/heartbeat_consumer.go"
  "idempotent" = @("docs/knowledge/cpemon-writer-kafka-consumer-refactor.md", "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md")
}

foreach ($token in $checks.Keys) {
  $matches = Select-String -Path $checks[$token] -Pattern $token -SimpleMatch
  if (-not $matches) {
    throw "Missing required token '$token' in $($checks[$token] -join ', ')"
  }
}

Write-Host "cpemon-writer heartbeat write model verification passed."
