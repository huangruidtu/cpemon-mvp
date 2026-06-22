$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbookPath = Join-Path $root "ops/runbooks/argocd-operations.md"
$adrPath = Join-Path $root "ADR/cloud-platform-upgrade-argocd-gitops-deployment.md"
$knowledgePath = Join-Path $root "docs/knowledge/argocd-gitops-deployment.md"
$knowledgeIndexPath = Join-Path $root "docs/knowledge/README.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-17-argocd-gitops-deployment.md"
$interviewIndexPath = Join-Path $root "docs/knowledge/interview/README.md"

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

foreach ($path in @($runbookPath, $adrPath, $knowledgePath, $knowledgeIndexPath, $interviewPath, $interviewIndexPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing required Argo CD final documentation file: $path"
    }
}

foreach ($snippet in @(
    "OutOfSync Troubleshooting",
    "Degraded Troubleshooting",
    "Missing CRD",
    "Wrong Path Or Source",
    "Bad Image Tag",
    "Permission Failures",
    "Rollback",
    "Application Inventory"
)) {
    Assert-Contains $runbookPath $snippet
}

foreach ($snippet in @(
    "Decision",
    "Alternatives Considered",
    "Consequences",
    "Deferred Hardening",
    "Rollback",
    "Interview Answer"
)) {
    Assert-Contains $adrPath $snippet
}

Assert-Contains $knowledgePath "CCPU-180: Document Argo CD Runbook, ADR, and Interview Notes"
Assert-Contains $knowledgeIndexPath "Argo CD Operations Runbook"
Assert-Contains $knowledgeIndexPath "Argo CD GitOps Deployment Decision"
Assert-Contains $interviewPath "Q66: What did CCPU-180 add?"
Assert-Contains $interviewIndexPath "why GitHub Actions remains CI while Argo CD owns CD"
Assert-Contains $interviewIndexPath "how to debug OutOfSync, Degraded, missing CRDs, bad image tags, wrong paths, and AppProject permission failures"

Write-Host "Argo CD runbook, ADR, and interview documentation passed."
