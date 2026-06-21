$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
  "k8s/addons/kafka/values.yaml",
  "ops/runbooks/kafka-platform-helm.md",
  "docs/knowledge/kafka-platform-introduction.md",
  "docs/knowledge/interview/story-14-kafka-platform-introduction.md",
  "Makefile"
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path $path)) {
    throw "Missing required Kafka Helm workflow file: $file"
  }
}

$makefile = Get-Content (Join-Path $root "Makefile") -Raw
$requiredTargets = @(
  "kafka-chart-show:",
  "kafka-template:",
  "kafka:",
  "kafka-check:",
  "kafka-validate:"
)

foreach ($target in $requiredTargets) {
  if ($makefile -notmatch [regex]::Escape($target)) {
    throw "Missing Makefile target: $target"
  }
}

$values = Get-Content (Join-Path $root "k8s/addons/kafka/values.yaml") -Raw
$requiredValues = @(
  "controller:",
  "replicaCount: 1",
  "kraft:",
  "enabled: true",
  "externalAccess:",
  "persistence:"
)

foreach ($needle in $requiredValues) {
  if ($values -notmatch [regex]::Escape($needle)) {
    throw "Kafka values file is missing expected content: $needle"
  }
}

$runbook = Get-Content (Join-Path $root "ops/runbooks/kafka-platform-helm.md") -Raw
if ($runbook -notmatch "KAFKA_BOOTSTRAP_SERVERS") {
  throw "Kafka runbook must document the bootstrap server contract."
}

$helm = Get-Command helm -ErrorAction SilentlyContinue
if ($null -eq $helm) {
  Write-Host "Helm is not available on PATH. Repository workflow validation passed; live Helm render/install remains blocked."
  exit 0
}

Write-Host "Helm detected: $($helm.Source)"
helm version --short
Write-Host "Repository workflow validation passed. Run 'make kafka-template' for chart render validation."
