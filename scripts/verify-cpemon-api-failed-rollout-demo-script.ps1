$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $root "scripts/demo-cpemon-api-failed-rollout.ps1"
$demoPath = Join-Path $root "ops/demos/argo-rollouts/cpemon-api-failed-canary.md"
$runbookPath = Join-Path $root "ops/runbooks/argo-rollouts-cpemon-api.md"
$knowledgePath = Join-Path $root "docs/knowledge/argo-rollouts-canary-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-19-argo-rollouts-canary-deployment.md"

function Assert-File {
    param([string] $Path)
    if (-not (Test-Path $Path)) {
        throw "Missing required file: $Path"
    }
}

function Assert-Contains {
    param(
        [string] $Path,
        [string] $Needle
    )
    $content = Get-Content -Raw $Path
    if (-not $content.Contains($Needle)) {
        throw "Expected '$Path' to contain '$Needle'"
    }
}

Assert-File $scriptPath
Assert-File $demoPath
Assert-File $runbookPath
Assert-File $knowledgePath
Assert-File $interviewPath

foreach ($needle in @(
    '[switch] $Execute',
    "Mode:",
    "kubectl argo rollouts get rollout",
    "kubectl get endpoints",
    "kubectl get analysisrun",
    "kubectl describe analysisrun",
    "kubectl describe rollout",
    "kubectl argo rollouts abort",
    "Failed demo evidence to explain"
)) {
    Assert-Contains $scriptPath $needle
}

Assert-Contains $demoPath "Scripted Demo"
Assert-Contains $demoPath "scripts/demo-cpemon-api-failed-rollout.ps1 -Execute"
Assert-Contains $runbookPath "Scripted failed demo"
Assert-Contains $knowledgePath "CCPU-195: Failed Rollout Demo Script"
Assert-Contains $interviewPath "Q43: What does the failed rollout script prove?"
Assert-Contains $interviewPath "Q44: Why is abort part of the demo instead of only watching failure?"

$output = & powershell -ExecutionPolicy Bypass -File $scriptPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Failed rollout demo script dry-run failed: $output"
}
$outputText = $output -join "`n"
foreach ($needle in @(
    "Mode: DRY-RUN",
    "Dry-run note",
    "Abort unsafe canary",
    "Verify stable path after abort"
)) {
    if (-not $outputText.Contains($needle)) {
        throw "Dry-run output missing expected text: $needle"
    }
}

Write-Host "CPEmon API failed rollout demo script validation passed."
