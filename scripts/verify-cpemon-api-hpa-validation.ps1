$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbookPath = Join-Path $root "ops/runbooks/cpemon-api-hpa-validation-load-test.md"
$hpaRunbookPath = Join-Path $root "ops/runbooks/cpemon-api-hpa.md"
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

foreach ($path in @($runbookPath, $hpaRunbookPath, $knowledgePath, $interviewPath, $readmePath)) {
    Assert-File $path
}

Assert-Contains $runbookPath "cpemon-api HPA Validation and Load-Test Runbook"
Assert-Contains $runbookPath "kubectl get apiservice v1beta1.metrics.k8s.io"
Assert-Contains $runbookPath "kubectl describe hpa cpemon-api-hpa -n cpemon"
Assert-Contains $runbookPath "kubectl run cpemon-api-loadtest"
Assert-Contains $runbookPath "Confirm metrics-server is healthy"
Assert-Contains $runbookPath "Disable autoscaling for the environment"
Assert-Contains $hpaRunbookPath "Live Validation"
Assert-Contains $knowledgePath "CCPU-210: HPA Validation and Dev Load Test"
Assert-Contains $interviewPath "Q43: What did CCPU-210 add?"
Assert-Contains $readmePath "cpemon-api HPA Validation and Load-Test Runbook"

Write-Host "cpemon-api HPA validation runbook check passed."
