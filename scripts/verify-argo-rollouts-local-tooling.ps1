param(
    [switch] $RequireInstalledPlugin
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbookPath = Join-Path $root "ops/runbooks/argo-rollouts-controller.md"
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
    if ($content -notlike "*$Needle*") {
        throw "Expected '$Path' to contain '$Needle'"
    }
}

Assert-File $runbookPath
Assert-File $knowledgePath
Assert-File $interviewPath

Assert-Contains $runbookPath "Local kubectl Plugin"
Assert-Contains $runbookPath "kubectl argo rollouts version"
Assert-Contains $runbookPath "kubectl plugin list"
Assert-Contains $runbookPath "kubectl-argo-rollouts.exe"
Assert-Contains $runbookPath "v1.9.0+838d4e7"
Assert-Contains $knowledgePath "CCPU-188: Add Argo Rollouts kubectl Plugin and Local Tooling"
Assert-Contains $knowledgePath "Operator tooling path"
Assert-Contains $knowledgePath "kubectl argo rollouts"
Assert-Contains $interviewPath "Q8: Why add the kubectl Argo Rollouts plugin?"
Assert-Contains $interviewPath "Q10: What local tooling issue did you validate on Windows?"

if ($RequireInstalledPlugin) {
    $plugin = Get-Command kubectl-argo-rollouts -ErrorAction SilentlyContinue
    if (-not $plugin) {
        throw "kubectl-argo-rollouts is not on PATH. Install the plugin or add its directory to PATH before running live rollout commands."
    }

    $version = & kubectl argo rollouts version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl argo rollouts version failed: $version"
    }

    if (($version -join "`n") -notlike "*v1.9.0*") {
        throw "Expected Argo Rollouts kubectl plugin v1.9.0, got: $version"
    }
}

Write-Host "Argo Rollouts local tooling validation passed."
