$ErrorActionPreference = "Stop"

$files = @(
  "app/pkg/config/config.go",
  "app/pkg/config/config_test.go",
  "deploy/helm/cpemon/values.yaml",
  "deploy/helm/cpemon/values-dev.yaml",
  "deploy/helm/cpemon/templates/configmap.yaml",
  "k8s/app/cpemon-app-config.yaml",
  "k8s/app/cpemon-writer.yaml",
  "ops/runbooks/cpemon-writer-kafka-consumer-group.md",
  "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md",
  "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
)

foreach ($file in $files) {
  if (-not (Test-Path $file)) {
    throw "Missing required file: $file"
  }
}

$checks = @{
  "DefaultKafkaConsumerGroupID" = "app/pkg/config/config.go"
  "KAFKA_CONSUMER_GROUP_ID" = $files
  "cpemon-writer" = $files
  "kafkaConsumerGroupId" = @("deploy/helm/cpemon/values.yaml", "deploy/helm/cpemon/values-dev.yaml")
  "kafka-consumer-groups.sh" = "ops/runbooks/cpemon-writer-kafka-consumer-group.md"
  "CURRENT-OFFSET" = "ops/runbooks/cpemon-writer-kafka-consumer-group.md"
  "LAG" = "ops/runbooks/cpemon-writer-kafka-consumer-group.md"
}

foreach ($token in $checks.Keys) {
  $paths = $checks[$token]
  $matches = Select-String -Path $paths -Pattern $token -SimpleMatch
  if (-not $matches) {
    throw "Missing required token '$token' in $($paths -join ', ')"
  }
}

Write-Host "cpemon-writer Kafka consumer group verification passed."
