$ErrorActionPreference = "Stop"

$files = @{
  Config = "app/pkg/config/config.go"
  ConfigTest = "app/pkg/config/config_test.go"
  Values = "deploy/helm/cpemon/values.yaml"
  Template = "deploy/helm/cpemon/templates/configmap.yaml"
  Schema = "deploy/helm/cpemon/values.schema.json"
  RawConfigMap = "k8s/app/cpemon-app-config.yaml"
  Doc = "docs/knowledge/acs-ingest-kafka-producer-refactor.md"
  Interview = "docs/knowledge/interview/story-15-acs-ingest-kafka-producer-refactor.md"
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) {
    throw "Missing expected Kafka producer config artifact: $path"
  }
}

$requiredEnv = @(
  "KAFKA_PRODUCER_ENABLED",
  "KAFKA_BOOTSTRAP_SERVERS",
  "KAFKA_TOPIC_DEVICE_HEARTBEAT",
  "KAFKA_TOPIC_WAN_STATUS",
  "KAFKA_TOPIC_DEADLETTER",
  "KAFKA_PRODUCER_TIMEOUT",
  "KAFKA_PRODUCER_MAX_RETRIES"
)

foreach ($entry in @(
  @{ Name = "Config"; Path = $files.Config },
  @{ Name = "ConfigTest"; Path = $files.ConfigTest },
  @{ Name = "Template"; Path = $files.Template },
  @{ Name = "RawConfigMap"; Path = $files.RawConfigMap },
  @{ Name = "Doc"; Path = $files.Doc }
)) {
  $text = Get-Content $entry.Path -Raw
  foreach ($envName in $requiredEnv) {
    if ($text -notmatch [regex]::Escape($envName)) {
      throw "$($entry.Name) is missing expected config key: $envName"
    }
  }
}

$helmKeys = @(
  "kafkaProducerEnabled",
  "kafkaBootstrapServers",
  "kafkaTopicDeviceHeartbeat",
  "kafkaTopicWanStatus",
  "kafkaTopicDeadletter",
  "kafkaProducerTimeout",
  "kafkaProducerMaxRetries"
)

foreach ($entry in @(
  @{ Name = "Values"; Path = $files.Values },
  @{ Name = "Schema"; Path = $files.Schema }
)) {
  $text = Get-Content $entry.Path -Raw
  foreach ($key in $helmKeys) {
    if ($text -notmatch [regex]::Escape($key)) {
      throw "$($entry.Name) is missing expected Helm value key: $key"
    }
  }
}

$interviewText = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "CCPU-162",
  "Why add config before implementing the producer?",
  "KAFKA_PRODUCER_ENABLED",
  "bootstrap",
  "topic"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Interview notes are missing expected content: $snippet"
  }
}

$configText = Get-Content $files.Config -Raw
foreach ($snippet in @(
  "KafkaProducerEnabled",
  "KafkaBootstrapServers",
  "KafkaTopicDeviceHeartbeat",
  "KafkaTopicWANStatus",
  "KafkaTopicDeadletter",
  "KafkaProducerTimeout",
  "KafkaProducerMaxRetries",
  "getenvBool",
  "getenvDuration",
  "getenvPositiveInt"
)) {
  if ($configText -notmatch [regex]::Escape($snippet)) {
    throw "Config loader is missing expected content: $snippet"
  }
}

$schema = Get-Content $files.Schema -Raw | ConvertFrom-Json
if (-not $schema.properties.appConfig.properties.kafkaProducerEnabled) {
  throw "values.schema.json is missing appConfig.kafkaProducerEnabled"
}
if (-not $schema.properties.appConfig.properties.kafkaProducerTimeout) {
  throw "values.schema.json is missing appConfig.kafkaProducerTimeout"
}
if (-not $schema.properties.appConfig.properties.kafkaProducerMaxRetries) {
  throw "values.schema.json is missing appConfig.kafkaProducerMaxRetries"
}

Write-Host "acs-ingest Kafka producer config validation passed."
