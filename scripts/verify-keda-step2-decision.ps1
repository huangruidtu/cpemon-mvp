$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$adrPath = Join-Path $root "ADR/cloud-platform-upgrade-hpa-first-keda-step2.md"
$runbookPath = Join-Path $root "ops/runbooks/keda-step2-decision.md"
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

foreach ($path in @($adrPath, $runbookPath, $knowledgePath, $interviewPath, $readmePath)) {
    Assert-File $path
}

Assert-Contains $adrPath "ADR: HPA First, KEDA Step 2"
Assert-Contains $adrPath "Use HPA first"
Assert-Contains $adrPath "Defer KEDA to Step 2"
Assert-Contains $adrPath "cpemon-writer replicas from Kafka consumer lag"
Assert-Contains $runbookPath "KEDA Step 2 Decision Runbook"
Assert-Contains $runbookPath "Future KEDA Readiness Checklist"
Assert-Contains $runbookPath "kind: ScaledObject"
Assert-Contains $knowledgePath "CCPU-211: KEDA Step 2 Decision"
Assert-Contains $interviewPath "Q47: What did CCPU-211 add?"
Assert-Contains $readmePath "KEDA Step 2 Decision Runbook"
Assert-Contains $readmePath "HPA First, KEDA Step 2 ADR"

Write-Host "KEDA Step 2 decision validation passed."
