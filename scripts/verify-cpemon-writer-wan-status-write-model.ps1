$ErrorActionPreference = "Stop"

$files = @(
  "app/cpemon-writer/wan_status_consumer.go",
  "app/cpemon-writer/wan_status_consumer_test.go",
  "app/pkg/events/wan_status.go",
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
  "decodeWANStatusWrite" = @("app/cpemon-writer/wan_status_consumer.go", "app/cpemon-writer/wan_status_consumer_test.go")
  "processWANStatusConsumedEvent" = @("app/cpemon-writer/wan_status_consumer.go", "app/cpemon-writer/wan_status_consumer_test.go")
  "writeWANStatus" = @("app/cpemon-writer/wan_status_consumer.go", "app/cpemon-writer/wan_status_consumer_test.go")
  "WANStatusEvent" = @("app/cpemon-writer/wan_status_consumer.go", "app/pkg/events/wan_status.go")
  "INSERT INTO cpe_status" = "app/cpemon-writer/wan_status_consumer.go"
  "INSERT INTO cpe_status_history" = "app/cpemon-writer/wan_status_consumer.go"
  "wan_ip" = @("app/cpemon-writer/wan_status_consumer.go", "sql/schema.sql")
  "sw_version" = @("app/cpemon-writer/wan_status_consumer.go", "sql/schema.sql")
  "COALESCE" = "app/cpemon-writer/wan_status_consumer.go"
  "idempotent" = @("docs/knowledge/cpemon-writer-kafka-consumer-refactor.md", "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md")
}

foreach ($token in $checks.Keys) {
  $matches = Select-String -Path $checks[$token] -Pattern $token -SimpleMatch
  if (-not $matches) {
    throw "Missing required token '$token' in $($checks[$token] -join ', ')"
  }
}

Write-Host "cpemon-writer WAN status write model verification passed."
