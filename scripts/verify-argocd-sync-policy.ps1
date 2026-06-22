$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationDir = Join-Path $root "k8s/gitops/dev/applications"
$runbookPath = Join-Path $root "ops/runbooks/argocd-sync-policy.md"
$knowledgePath = Join-Path $root "docs/knowledge/argocd-gitops-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-17-argocd-gitops-deployment.md"

$applications = @(
    "cpemon-dev.yaml",
    "kafka-dev.yaml",
    "monitoring-dev.yaml",
    "external-secrets-dev.yaml",
    "kyverno-dev.yaml",
    "kyverno-policies-dev.yaml",
    "opencost-dev.yaml",
    "policy-security-dev.yaml"
)

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

foreach ($app in $applications) {
    $path = Join-Path $applicationDir $app
    if (-not (Test-Path $path)) {
        throw "Missing Argo CD Application: $app"
    }

    Assert-Contains $path "cpemon.io/sync-policy: manual"
    Assert-Contains $path 'cpemon.io/sync-prune: "disabled"'
    Assert-Contains $path 'cpemon.io/sync-self-heal: "disabled"'

    $content = Get-Content -Raw $path
    if ($content -like "*automated:*") {
        throw "Application '$app' enables automated sync; CCPU-101 expects manual sync."
    }
}

foreach ($path in @($runbookPath, $knowledgePath, $interviewPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing sync policy documentation file: $path"
    }
}

Assert-Contains $runbookPath "automated sync: disabled"
Assert-Contains $runbookPath "Argo CD sync is reconciliation from Git to the cluster"
Assert-Contains $knowledgePath "CCPU-101: Configure Sync Policy"
Assert-Contains $interviewPath "Q41: What did CCPU-101 add?"

Write-Host "Argo CD sync policy validation passed."
