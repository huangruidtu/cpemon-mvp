$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $root "scripts/demo-cpemon-api-successful-rollout.ps1"
$demoPath = Join-Path $root "ops/demos/argo-rollouts/cpemon-api-healthy-canary.md"
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
    "helm template",
    "kubectl argo rollouts get rollout",
    "kubectl get endpoints",
    "kubectl get analysisrun",
    "kubectl describe analysisrun",
    "kubectl argo rollouts promote",
    "Successful demo evidence to explain"
)) {
    Assert-Contains $scriptPath $needle
}

Assert-Contains $demoPath "Scripted Demo"
Assert-Contains $demoPath "scripts/demo-cpemon-api-successful-rollout.ps1 -Execute"
Assert-Contains $runbookPath "Scripted successful demo"
Assert-Contains $knowledgePath "CCPU-194: Successful Rollout Demo Script"
Assert-Contains $interviewPath "Q41: Why make the successful demo script default to dry-run?"
Assert-Contains $interviewPath "Q42: What evidence does the successful demo script collect?"

$output = & powershell -ExecutionPolicy Bypass -File $scriptPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Successful rollout demo script dry-run failed: $output"
}
$outputText = $output -join "`n"
foreach ($needle in @(
    "Mode: DRY-RUN",
    "Dry-run note",
    "Promote at the first healthy pause",
    "Verify final healthy rollout"
)) {
    if (-not $outputText.Contains($needle)) {
        throw "Dry-run output missing expected text: $needle"
    }
}

Write-Host "CPEmon API successful rollout demo script validation passed."
