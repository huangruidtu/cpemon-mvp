$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
  "ADR/cloud-platform-upgrade-kafka-platform-architecture.md",
  "docs/knowledge/kafka-platform-architecture-migration.md"
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path $path)) {
    throw "Missing Kafka architecture document: $file"
  }
}

$combined = ""
foreach ($file in $requiredFiles) {
  $combined += Get-Content (Join-Path $root $file) -Raw
}

$requiredSnippets = @(
  "CCPU-159",
  "MySQL queue tables",
  "Kafka platform",
  "future producer integration",
  "future consumer integration",
  "KAFKA_BOOTSTRAP_SERVERS",
  "Story 8 does not",
  "platform contract first",
  "queue retirement last",
  "mermaid"
)

foreach ($snippet in $requiredSnippets) {
  if ($combined -notmatch [regex]::Escape($snippet)) {
    throw "Kafka architecture docs are missing expected content: $snippet"
  }
}

Write-Host "Kafka architecture documentation validation passed."
