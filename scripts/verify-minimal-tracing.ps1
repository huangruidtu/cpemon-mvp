$ErrorActionPreference = "Stop"

$trace = "app/pkg/tracecontext/tracecontext.go"
$test = "app/pkg/tracecontext/tracecontext_test.go"
$api = "app/cpemon-api/main.go"
$knowledge = "docs/knowledge/monitoring-observability-upgrade.md"
$interview = "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"

foreach ($path in @($trace, $test, $api, $knowledge, $interview)) {
  if (!(Test-Path $path)) { throw "Missing expected file: $path" }
}

function Assert-Contains {
  param([string]$Path, [string]$Needle)
  $content = Get-Content -Raw $Path
  if ($content -notlike "*$Needle*") { throw "Expected '$Needle' in $Path" }
}

foreach ($snippet in @("traceparent", "X-Trace-Id", "FromHTTPHeader", "WithTrace", "TraceID")) {
  Assert-Contains $trace $snippet
}
Assert-Contains $api "traceContextMiddleware"
Assert-Contains $api "tracecontext.FromHTTPHeader"
Assert-Contains $test "TestFromHTTPHeaderUsesTraceparent"
Assert-Contains $knowledge "CCPU-184 Learning Notes"
Assert-Contains $interview "traces as latency path evidence"

Write-Host "Minimal tracing verification passed."
