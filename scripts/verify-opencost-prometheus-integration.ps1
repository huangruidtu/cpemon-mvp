$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$valuesPath = Join-Path $root "k8s/addons/opencost/values.yaml"
$runbookPath = Join-Path $root "ops/runbooks/opencost-prometheus-integration.md"
$installRunbookPath = Join-Path $root "ops/runbooks/argocd-opencost-installation.md"
$operationsRunbookPath = Join-Path $root "ops/runbooks/argocd-operations.md"
$knowledgePath = Join-Path $root "docs/knowledge/platform-governance-cost-autoscaling.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-20-platform-governance-cost-autoscaling.md"

function Assert-File {
    param([string] $Path)
    if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
}

function Assert-Contains {
    param([string] $Path, [string] $Needle)
    $content = Get-Content -Raw $Path
    if ($content -notlike "*$Needle*") { throw "Expected '$Path' to contain '$Needle'" }
}

foreach ($path in @($valuesPath, $runbookPath, $installRunbookPath, $operationsRunbookPath, $knowledgePath, $interviewPath)) {
    Assert-File $path
}

Assert-Contains $valuesPath "prometheus:"
Assert-Contains $valuesPath "internal:"
Assert-Contains $valuesPath "enabled: true"
Assert-Contains $valuesPath "serviceName: kps-kube-prometheus-stack-prometheus"
Assert-Contains $valuesPath "namespaceName: monitoring"
Assert-Contains $valuesPath "port: 9090"
Assert-Contains $valuesPath "external:"
Assert-Contains $valuesPath "enabled: false"

Assert-Contains $runbookPath "http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
Assert-Contains $runbookPath "monitoring-dev"
Assert-Contains $runbookPath "opencost-dev"
Assert-Contains $runbookPath "allocation/compute"
Assert-Contains $installRunbookPath "Prometheus connection details"
Assert-Contains $operationsRunbookPath "OpenCost can be synced after monitoring"
Assert-Contains $knowledgePath "CCPU-206: OpenCost Prometheus Integration"
Assert-Contains $interviewPath "Q29: What did CCPU-206 add?"

Write-Host "OpenCost Prometheus integration validation passed."
