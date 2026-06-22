$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

function Assert-File {
    param([string] $Path)
    if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
}

function Assert-Contains {
    param([string] $Path, [string] $Needle)
    $content = Get-Content -Raw $Path
    if ($content -notlike "*$Needle*") { throw "Expected '$Path' to contain '$Needle'" }
}

$requiredFiles = @(
    "ops/runbooks/platform-governance-cost-autoscaling-final-checklist.md",
    "ops/runbooks/platform-governance-boundary.md",
    "ops/runbooks/argocd-kyverno-installation.md",
    "ops/runbooks/kyverno-resource-policy.md",
    "ops/runbooks/kyverno-image-tag-policy.md",
    "ops/runbooks/kyverno-labels-nonroot-policies.md",
    "ops/runbooks/kyverno-policy-fixtures.md",
    "ops/runbooks/argocd-opencost-installation.md",
    "ops/runbooks/opencost-prometheus-integration.md",
    "ops/runbooks/opencost-namespace-cost-visibility.md",
    "ops/runbooks/opencost-cost-investigation.md",
    "ops/runbooks/cpemon-api-hpa.md",
    "ops/runbooks/cpemon-api-hpa-validation-load-test.md",
    "ops/runbooks/keda-step2-decision.md",
    "ops/runbooks/platform-governance-cost-autoscaling-interview.md",
    "ADR/cloud-platform-upgrade-governance-cost-autoscaling.md",
    "ADR/cloud-platform-upgrade-hpa-first-keda-step2.md",
    "docs/knowledge/platform-governance-cost-autoscaling.md",
    "docs/knowledge/interview/story-20-platform-governance-cost-autoscaling.md",
    "docs/knowledge/README.md",
    "scripts/verify-platform-governance-boundary.ps1",
    "scripts/verify-argocd-kyverno-installation.ps1",
    "scripts/verify-kyverno-resource-policy.ps1",
    "scripts/verify-kyverno-image-tag-policy.ps1",
    "scripts/verify-kyverno-labels-nonroot-policies.ps1",
    "scripts/verify-kyverno-policy-fixtures.ps1",
    "scripts/verify-argocd-opencost-installation.ps1",
    "scripts/verify-opencost-prometheus-integration.ps1",
    "scripts/verify-opencost-namespace-cost-visibility.ps1",
    "scripts/verify-opencost-cost-investigation.ps1",
    "scripts/verify-cpemon-api-hpa.ps1",
    "scripts/verify-cpemon-api-hpa-validation.ps1",
    "scripts/verify-keda-step2-decision.ps1",
    "scripts/verify-platform-governance-cost-autoscaling-docs.ps1"
)

foreach ($relative in $requiredFiles) {
    Assert-File (Join-Path $root $relative)
}

$checklistPath = Join-Path $root "ops/runbooks/platform-governance-cost-autoscaling-final-checklist.md"
$knowledgePath = Join-Path $root "docs/knowledge/platform-governance-cost-autoscaling.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-20-platform-governance-cost-autoscaling.md"
$readmePath = Join-Path $root "docs/knowledge/README.md"
$makefilePath = Join-Path $root "Makefile"

Assert-Contains $checklistPath "Platform Governance, Cost Visibility, and Autoscaling Final Checklist"
Assert-Contains $checklistPath "Runbook Index"
Assert-Contains $checklistPath "Local Validation"
Assert-Contains $checklistPath "Live Cluster Checks"
Assert-Contains $checklistPath "Interview Rehearsal Checklist"
Assert-Contains $checklistPath "Final Story Answer"
Assert-Contains $knowledgePath "CCPU-213: Final Validation Checklist and Story Index"
Assert-Contains $interviewPath "Q55: What did CCPU-213 add?"
Assert-Contains $readmePath "Platform Governance, Cost Visibility, and Autoscaling Final Checklist"
Assert-Contains $makefilePath "platform-governance-cost-autoscaling-final-check"

Write-Host "Platform governance, cost, and autoscaling final validation passed."
