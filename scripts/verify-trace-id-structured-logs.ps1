$ErrorActionPreference = "Stop"

function Assert-Contains {
  param(
    [string]$Path,
    [string]$Needle
  )
  $content = Get-Content -Raw $Path
  if (-not $content.Contains($Needle)) {
    throw "$Path does not contain expected text: $Needle"
  }
}

$api = "app/cpemon-api/main.go"
$runbook = "ops/runbooks/monitoring-observability.md"
$knowledge = "docs/knowledge/monitoring-observability-upgrade.md"
$interview = "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"

Assert-Contains $api "traceLoggingMiddleware"
Assert-Contains $api "event=http_request service=cpemon-api trace_id=%s"
Assert-Contains $api "tracecontext.TraceID(c.Request.Context())"
Assert-Contains $api "route := c.FullPath()"
Assert-Contains $api "duration_ms=%d"

Assert-Contains $runbook "trace_id structured logs"
Assert-Contains $runbook "event=http_request service=cpemon-api"
Assert-Contains $knowledge "CCPU-185 Learning Notes: trace_id structured logs"
Assert-Contains $knowledge "metric symptom -> dashboard -> trace_id -> logs"
Assert-Contains $interview "Q19: Why put trace_id into structured logs?"

Write-Host "trace_id structured log checks passed"
