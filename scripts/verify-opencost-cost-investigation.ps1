$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbookPath = Join-Path $root "ops/runbooks/opencost-cost-investigation.md"
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

Assert-Contains $runbookPath "kubectl port-forward -n opencost svc/opencost 9003:9003"
Assert-Contains $runbookPath "allocation/compute?window=1h&aggregate=namespace"
Assert-Contains $runbookPath "Incident Drill: Kafka Namespace Cost Increase"
Assert-Contains $runbookPath "filter=namespace:kafka"
Assert-Contains $runbookPath "kubectl get pods,svc,statefulset,pvc -n kafka"
Assert-Contains $runbookPath "argocd app history kafka-dev"
Assert-Contains $runbookPath "Cleanup And Resource Review Checklist"
Assert-Contains $knowledgePath "CCPU-208: OpenCost Access and Cost Investigation"
Assert-Contains $interviewPath "Q36: What did CCPU-208 add?"
Assert-Contains $readmePath "OpenCost Access and Cost Investigation Runbook"

Write-Host "OpenCost cost investigation validation passed."
