$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbookPath = Join-Path $root "ops/runbooks/opencost-namespace-cost-visibility.md"
$knowledgePath = Join-Path $root "docs/knowledge/platform-governance-cost-autoscaling.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-20-platform-governance-cost-autoscaling.md"
$readmePath = Join-Path $root "docs/knowledge/README.md"

function Assert-File {
    param([string] $Path)
    if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
}

function Assert-Contains {
    param([string] $Path, [string] $Needle)
    $content = Get-Content -Raw $Path
    if ($content -notlike "*$Needle*") { throw "Expected '$Path' to contain '$Needle'" }
}

foreach ($path in @($runbookPath, $knowledgePath, $interviewPath, $readmePath)) {
    Assert-File $path
}

foreach ($namespace in @("cpemon", "kafka", "monitoring", "argocd", "kyverno", "opencost")) {
    Assert-Contains $runbookPath $namespace
}

Assert-Contains $runbookPath "allocation/compute?window=1h&aggregate=namespace"
Assert-Contains $runbookPath "visibility first, not production chargeback"
Assert-Contains $runbookPath "Do Not Overclaim"
Assert-Contains $runbookPath "Prometheus Cross-Check"
Assert-Contains $knowledgePath "CCPU-207: Namespace-Level Cost Visibility"
Assert-Contains $interviewPath "Q33: What did CCPU-207 add?"
Assert-Contains $readmePath "OpenCost Namespace Cost Visibility Runbook"

Write-Host "OpenCost namespace cost visibility validation passed."
