$ErrorActionPreference = "Stop"

$files = @{
  Main = "app/cpemon-api/main.go"
  Runbook = "ops/runbooks/monitoring-observability.md"
  Knowledge = "docs/knowledge/monitoring-observability-upgrade.md"
  Interview = "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"
}

foreach ($path in $files.Values) {
  if (!(Test-Path $path)) {
    throw "Missing expected file: $path"
  }
}

function Assert-Contains {
  param([string]$Path, [string]$Needle)
  $content = Get-Content -Raw $Path
  if ($content -notlike "*$Needle*") {
    throw "Expected '$Needle' in $Path"
  }
}

foreach ($snippet in @(
  "cpemon_api_requests_total",
  "cpemon_api_http_requests_total",
  "cpemon_api_http_request_duration_seconds",
  "cpemonAPICollectors",
  "prometheusHTTPMiddleware",
  "c.FullPath()",
  "method",
  "route",
  "code"
)) {
  Assert-Contains $files.Main $snippet
}

foreach ($snippet in @(
  "API HTTP Metrics",
  "RED metrics",
  "cpemon_api_http_requests_total",
  "cpemon_api_http_request_duration_seconds"
)) {
  Assert-Contains $files.Runbook $snippet
  Assert-Contains $files.Knowledge $snippet
}

Assert-Contains $files.Interview "RED metrics"
Assert-Contains $files.Interview "route template"

Write-Host "cpemon-api HTTP metrics verification passed."
