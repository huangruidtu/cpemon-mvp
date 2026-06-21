$ErrorActionPreference = "Stop"

$requiredFiles = @(
  "app/pkg/config/config.go",
  "app/pkg/config/config_test.go",
  "deploy/helm/cpemon/values.yaml",
  "deploy/helm/cpemon/values-dev.yaml",
  "deploy/helm/cpemon/templates/configmap.yaml",
  "deploy/helm/cpemon/values.schema.json",
  "k8s/app/cpemon-app-config.yaml",
  "k8s/app/cpemon-writer.yaml",
  "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md",
  "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
)

foreach ($file in $requiredFiles) {
  if (-not (Test-Path $file)) {
    throw "Missing required file: $file"
  }
}

$requiredTokens = @(
  "KAFKA_CONSUMER_ENABLED",
  "KAFKA_CONSUMER_GROUP_ID",
  "KAFKA_CONSUMER_READ_TIMEOUT",
  "KAFKA_CONSUMER_COMMIT_TIMEOUT",
  "KAFKA_CONSUMER_MAX_RETRIES",
  "KAFKA_CONSUMER_RETRY_BACKOFF",
  "cpemon-writer",
  "kafkaConsumerEnabled",
  "kafkaConsumerGroupId"
)

$searchFiles = $requiredFiles | Where-Object { $_ -notlike "scripts/*" }

foreach ($token in $requiredTokens) {
  $matches = Select-String -Path $searchFiles -Pattern $token -SimpleMatch
  if (-not $matches) {
    throw "Missing required token across config/docs: $token"
  }
}

Write-Host "cpemon-writer Kafka consumer config verification passed."
