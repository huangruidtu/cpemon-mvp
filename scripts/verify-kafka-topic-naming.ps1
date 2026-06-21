$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$doc = Join-Path $root "docs/knowledge/kafka-topic-naming-convention.md"

if (-not (Test-Path $doc)) {
  throw "Missing Kafka topic naming convention document."
}

$content = Get-Content $doc -Raw
$requiredSnippets = @(
  "CCPU-75",
  "cpemon.<domain>.<event-family>.v<major>",
  "cpemon.device.heartbeat.v1",
  "cpemon.wan.status.v1",
  "cpemon.deadletter.v1",
  "Do not put environment names in topic names",
  "Versioning Rule",
  "Dead-Letter Convention",
  "Bad Examples",
  "Interview Summary"
)

foreach ($snippet in $requiredSnippets) {
  if ($content -notmatch [regex]::Escape($snippet)) {
    throw "Kafka topic naming convention is missing expected content: $snippet"
  }
}

Write-Host "Kafka topic naming convention validation passed."
