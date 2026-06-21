$ErrorActionPreference = "Stop"

$files = @(
  "app/pkg/events/kafka_consumer.go",
  "app/pkg/events/kafka_consumer_test.go",
  "app/pkg/events/wan_status.go",
  "app/pkg/config/config.go",
  "deploy/helm/cpemon/values.yaml",
  "k8s/app/cpemon-app-config.yaml",
  "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md",
  "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
)

foreach ($file in $files) {
  if (-not (Test-Path $file)) {
    throw "Missing required file: $file"
  }
}

$checks = @{
  "WANStatusTopic" = @("app/pkg/events/kafka_consumer.go", "app/pkg/events/kafka_consumer_test.go", "app/pkg/events/wan_status.go")
  "KafkaConsumerTopicsFromConfig" = @("app/pkg/events/kafka_consumer.go", "app/pkg/events/kafka_consumer_test.go")
  "KAFKA_TOPIC_WAN_STATUS" = @("app/pkg/config/config.go", "deploy/helm/cpemon/values.yaml", "k8s/app/cpemon-app-config.yaml")
  "cpemon.wan.status.v1" = $files
  "WAN status topic" = @("docs/knowledge/cpemon-writer-kafka-consumer-refactor.md", "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md")
}

foreach ($token in $checks.Keys) {
  $matches = Select-String -Path $checks[$token] -Pattern $token -SimpleMatch
  if (-not $matches) {
    throw "Missing required token '$token' in $($checks[$token] -join ', ')"
  }
}

Write-Host "cpemon-writer WAN status subscription verification passed."
