$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$knowledgePath = Join-Path $root "docs/knowledge/platform-governance-cost-autoscaling.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-20-platform-governance-cost-autoscaling.md"
$runbookPath = Join-Path $root "ops/runbooks/platform-governance-boundary.md"
$knowledgeIndexPath = Join-Path $root "docs/knowledge/README.md"
$interviewIndexPath = Join-Path $root "docs/knowledge/interview/README.md"

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

foreach ($path in @($knowledgePath, $interviewPath, $runbookPath, $knowledgeIndexPath, $interviewIndexPath)) {
    Assert-File $path
}

foreach ($needle in @(
    "CCPU-199: Architecture Boundary",
    "Kyverno governance",
    "OpenCost",
    "HPA",
    "KEDA Is Step 2",
    "policy-as-code guardrails first"
)) {
    Assert-Contains $knowledgePath $needle
}

foreach ($needle in @(
    "Story 20 - Platform Governance, Cost Visibility, and Basic Autoscaling",
    "Q4: Why start with HPA instead of KEDA?",
    "Q5: What is platform-owned vs application-owned?",
    "60-second interview answer"
)) {
    Assert-Contains $interviewPath $needle
}

foreach ($needle in @(
    "Platform Governance, Cost Visibility, and Autoscaling Boundary",
    "Kyverno",
    "OpenCost",
    "kubectl get hpa -n cpemon",
    "complete security hardening"
)) {
    Assert-Contains $runbookPath $needle
}

Assert-Contains $knowledgeIndexPath "Platform Governance, Cost Visibility, and Basic Autoscaling"
Assert-Contains $interviewIndexPath "Story 20: Platform Governance, Cost Visibility, and Basic Autoscaling"

Write-Host "Platform governance architecture boundary validation passed."
