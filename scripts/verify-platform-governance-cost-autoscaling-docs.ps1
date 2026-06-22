$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$adrPath = Join-Path $root "ADR/cloud-platform-upgrade-governance-cost-autoscaling.md"
$kedaAdrPath = Join-Path $root "ADR/cloud-platform-upgrade-hpa-first-keda-step2.md"
$interviewRunbookPath = Join-Path $root "ops/runbooks/platform-governance-cost-autoscaling-interview.md"
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

foreach ($path in @($adrPath, $kedaAdrPath, $interviewRunbookPath, $knowledgePath, $interviewPath, $readmePath)) {
    Assert-File $path
}

Assert-Contains $adrPath "Platform Governance, Cost Visibility, and Basic Autoscaling"
Assert-Contains $adrPath "Governance:   Kyverno baseline policies"
Assert-Contains $adrPath "Cost:         OpenCost"
Assert-Contains $adrPath "Autoscaling:  HPA"
Assert-Contains $adrPath "Deferred:     KEDA"
Assert-Contains $interviewRunbookPath "One-Minute Story"
Assert-Contains $interviewRunbookPath "Problem -> Decision -> Tradeoff -> Validation -> Future work"
Assert-Contains $interviewRunbookPath "Red Flags To Avoid"
Assert-Contains $knowledgePath "CCPU-212: Governance, Cost, and Autoscaling ADRs"
Assert-Contains $interviewPath "Q51: What did CCPU-212 add?"
Assert-Contains $readmePath "Platform Governance, Cost, and Autoscaling ADR"
Assert-Contains $readmePath "Platform Governance, Cost, and Autoscaling Interview Notes"

Write-Host "Platform governance, cost, and autoscaling docs validation passed."
