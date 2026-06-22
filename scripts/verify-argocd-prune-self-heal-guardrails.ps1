$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationDir = Join-Path $root "k8s/gitops/dev/applications"
$runbookPath = Join-Path $root "ops/runbooks/argocd-prune-self-heal-guardrails.md"
$knowledgePath = Join-Path $root "docs/knowledge/argocd-gitops-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-17-argocd-gitops-deployment.md"

$applications = Get-ChildItem -Path $applicationDir -Filter "*.yaml"
if ($applications.Count -eq 0) {
    throw "No Argo CD Application manifests found in $applicationDir"
}

foreach ($application in $applications) {
    $content = Get-Content -Raw $application.FullName
    if ($content -notlike '*cpemon.io/sync-prune: "disabled"*') {
        throw "$($application.Name) does not declare prune disabled."
    }
    if ($content -notlike '*cpemon.io/sync-self-heal: "disabled"*') {
        throw "$($application.Name) does not declare self-heal disabled."
    }
    if ($content -like "*prune: true*") {
        throw "$($application.Name) enables prune."
    }
    if ($content -like "*selfHeal: true*") {
        throw "$($application.Name) enables selfHeal."
    }
}

foreach ($path in @($runbookPath, $knowledgePath, $interviewPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing guardrail documentation file: $path"
    }
}

$runbook = Get-Content -Raw $runbookPath
foreach ($snippet in @(
    "prune:     disabled",
    "self-heal: disabled",
    "Why Prune Needs Care",
    "Why Self-Heal Needs Care"
)) {
    if ($runbook -notlike "*$snippet*") {
        throw "Guardrail runbook is missing: $snippet"
    }
}

$knowledge = Get-Content -Raw $knowledgePath
if ($knowledge -notlike "*CCPU-178: Configure Self-Heal and Prune Guardrails*") {
    throw "Knowledge notes missing CCPU-178 section."
}

$interview = Get-Content -Raw $interviewPath
if ($interview -notlike "*Q46: What did CCPU-178 add?*") {
    throw "Interview notes missing CCPU-178 question."
}

Write-Host "Argo CD prune and self-heal guardrail validation passed."
