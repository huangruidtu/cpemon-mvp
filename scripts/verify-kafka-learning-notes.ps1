$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$doc = Join-Path $root "docs/knowledge/interview/kafka-platform-learning-notes.md"

if (-not (Test-Path $doc)) {
  throw "Missing Kafka platform learning notes."
}

$content = Get-Content $doc -Raw
$requiredSnippets = @(
  "CCPU-161",
  "60-Second Story",
  "Core Mental Model",
  "Key Concepts",
  "Broker",
  "Topic",
  "Partition",
  "Replication",
  "Bootstrap server",
  "Consumer group",
  "Dead-letter topic",
  "KAFKA_BOOTSTRAP_SERVERS",
  "Debugging Order",
  "STAR Story",
  "One-Line Resume Version"
)

foreach ($snippet in $requiredSnippets) {
  if ($content -notmatch [regex]::Escape($snippet)) {
    throw "Kafka learning notes are missing expected content: $snippet"
  }
}

Write-Host "Kafka learning notes validation passed."
