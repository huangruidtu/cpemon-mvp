$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$valuesFile = Join-Path $root "k8s/addons/kafka/values.yaml"

if (-not (Test-Path $valuesFile)) {
  throw "Missing Kafka values file: k8s/addons/kafka/values.yaml"
}

$content = Get-Content $valuesFile -Raw

$requiredSnippets = @(
  "provisioning:",
  "enabled: true",
  "cpemon.device.heartbeat.v1",
  "cpemon.wan.status.v1",
  "cpemon.deadletter.v1",
  "partitions: 1",
  "replicationFactor: 1",
  "retention.ms: `"604800000`""
)

foreach ($snippet in $requiredSnippets) {
  if ($content -notmatch [regex]::Escape($snippet)) {
    throw "Kafka topic contract is missing expected content: $snippet"
  }
}

Write-Host "Kafka topic contract validation passed."
