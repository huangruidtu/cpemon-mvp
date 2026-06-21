$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
  "deploy/helm/cpemon/values.yaml",
  "deploy/helm/cpemon/templates/configmap.yaml",
  "deploy/helm/cpemon/values.schema.json",
  "k8s/app/cpemon-app-config.yaml",
  "ops/runbooks/kafka-bootstrap-config.md"
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path $path)) {
    throw "Missing required Kafka config boundary file: $file"
  }
}

$requiredKeys = @(
  "KAFKA_BOOTSTRAP_SERVERS",
  "KAFKA_TOPIC_DEVICE_HEARTBEAT",
  "KAFKA_TOPIC_WAN_STATUS",
  "KAFKA_TOPIC_DEADLETTER"
)

$requiredValues = @(
  "kafka.kafka.svc.cluster.local:9092",
  "cpemon.device.heartbeat.v1",
  "cpemon.wan.status.v1",
  "cpemon.deadletter.v1"
)

$valueFilesToCheck = @(
  "deploy/helm/cpemon/values.yaml",
  "k8s/app/cpemon-app-config.yaml",
  "ops/runbooks/kafka-bootstrap-config.md"
)

foreach ($file in $valueFilesToCheck) {
  $content = Get-Content (Join-Path $root $file) -Raw
  foreach ($snippet in $requiredKeys + $requiredValues) {
    if ($content -notmatch [regex]::Escape($snippet)) {
      throw "$file is missing expected Kafka config content: $snippet"
    }
  }
}

$template = Get-Content (Join-Path $root "deploy/helm/cpemon/templates/configmap.yaml") -Raw
$templateRequired = @(
  "KAFKA_BOOTSTRAP_SERVERS",
  "KAFKA_TOPIC_DEVICE_HEARTBEAT",
  "KAFKA_TOPIC_WAN_STATUS",
  "KAFKA_TOPIC_DEADLETTER",
  "kafkaBootstrapServers",
  "kafkaTopicDeviceHeartbeat",
  "kafkaTopicWanStatus",
  "kafkaTopicDeadletter"
)

foreach ($snippet in $templateRequired) {
  if ($template -notmatch [regex]::Escape($snippet)) {
    throw "configmap.yaml is missing expected Kafka template content: $snippet"
  }
}

$schema = Get-Content (Join-Path $root "deploy/helm/cpemon/values.schema.json") -Raw
$schemaRequired = @(
  "kafkaBootstrapServers",
  "kafkaTopicDeviceHeartbeat",
  "kafkaTopicWanStatus",
  "kafkaTopicDeadletter"
)

foreach ($snippet in $schemaRequired) {
  if ($schema -notmatch [regex]::Escape($snippet)) {
    throw "values.schema.json is missing expected Kafka config schema field: $snippet"
  }
}

Write-Host "Kafka config boundary validation passed."
