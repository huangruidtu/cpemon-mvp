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

$adr = "ADR/cloud-platform-upgrade-monitoring-observability.md"
$runbook = "ops/runbooks/monitoring-observability.md"
$knowledge = "docs/knowledge/monitoring-observability-upgrade.md"
$interview = "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"
$index = "docs/knowledge/README.md"

foreach ($path in @($adr, $runbook, $knowledge, $interview, $index)) {
  if (-not (Test-Path $path)) {
    throw "Missing final observability documentation artifact: $path"
  }
}

Assert-Contains $adr "ADR: Monitoring and Observability Upgrade"
Assert-Contains $adr "Repository proof"
Assert-Contains $adr "Tempo is the first trace backend"
Assert-Contains $adr "trace_id"

foreach ($needle in @(
  "ServiceMonitor label mismatch",
  "wrong metrics path",
  "missing port name",
  "selector mismatch",
  "bad image metrics endpoint",
  "tracing gaps"
)) {
  Assert-Contains $runbook $needle
}

Assert-Contains $knowledge "Story 12 Final Interview Narrative"
Assert-Contains $knowledge "metrics, logs, traces, dashboards, and alerts"
Assert-Contains $interview "Q24: What is the final Story 12 interview summary?"
Assert-Contains $interview "Q25: What mistakes did you deliberately avoid?"
Assert-Contains $index "Monitoring and Observability Upgrade"
Assert-Contains $index "Monitoring Observability Runbook"
Assert-Contains $index "Monitoring and Observability Upgrade Decision"

Write-Host "final monitoring observability documentation checks passed"
