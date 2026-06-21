$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$namespaceFile = Join-Path $root "k8s/base/namespaces.yaml"

if (-not (Test-Path $namespaceFile)) {
  throw "Missing namespace manifest: k8s/base/namespaces.yaml"
}

$content = Get-Content $namespaceFile -Raw

$requiredSnippets = @(
  "kind: Namespace",
  "name: kafka",
  "app.kubernetes.io/part-of: cpemon-mvp",
  "app.kubernetes.io/name: kafka",
  "cpemon.io/layer: data-streaming",
  "cpemon.io/managed-by: gitops-ready-manifest"
)

foreach ($snippet in $requiredSnippets) {
  if ($content -notmatch [regex]::Escape($snippet)) {
    throw "Kafka namespace manifest is missing expected content: $snippet"
  }
}

Write-Host "Kafka namespace manifest validation passed."
