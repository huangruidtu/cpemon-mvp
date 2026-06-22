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

$collector = "k8s/observability/otel-collector.yaml"
$tempo = "k8s/observability/tempo.yaml"
$runbook = "ops/runbooks/monitoring-observability.md"
$knowledge = "docs/knowledge/monitoring-observability-upgrade.md"
$interview = "docs/knowledge/interview/story-18-monitoring-observability-upgrade.md"

foreach ($path in @($collector, $tempo, $runbook, $knowledge, $interview)) {
  if (-not (Test-Path $path)) {
    throw "Missing expected file: $path"
  }
}

Assert-Contains $collector "otlp/trace-backend:"
Assert-Contains $collector "endpoint: tempo.observability.svc.cluster.local:4317"
Assert-Contains $collector "exporters: [debug, otlp/trace-backend]"

Assert-Contains $tempo "kind: Deployment"
Assert-Contains $tempo "name: tempo"
Assert-Contains $tempo "image: grafana/tempo:2.6.1"
Assert-Contains $tempo "http_listen_port: 3200"
Assert-Contains $tempo "backend: local"
Assert-Contains $tempo "name: otlp-grpc"
Assert-Contains $tempo "name: otlp-http"

Assert-Contains $runbook "Trace backend: Tempo"
Assert-Contains $runbook "tempo.observability.svc.cluster.local:4317"
Assert-Contains $knowledge "CCPU-186 Learning Notes: Tempo trace export"
Assert-Contains $knowledge "Tempo is the first trace backend"
Assert-Contains $interview "Q20: Why choose Tempo before Jaeger here?"

Write-Host "trace export boundary checks passed"
