$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$appPath = Join-Path $root "k8s/gitops/dev/applications/crossplane-providers-dev.yaml"
$runbookPath = Join-Path $root "ops/runbooks/argocd-crossplane-wiring.md"
$knowledgePath = Join-Path $root "docs/knowledge/crossplane-developer-self-service.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-21-crossplane-developer-self-service.md"
$readmePath = Join-Path $root "docs/knowledge/README.md"
$makefilePath = Join-Path $root "Makefile"

function Assert-Exists {
    param([string]$Path)
    if (!(Test-Path $Path)) { throw "Expected file to exist: $Path" }
}

function Assert-Contains {
    param([string]$Path, [string]$Needle)
    $content = Get-Content $Path -Raw
    if ($content -notlike "*$Needle*") { throw "Expected '$Path' to contain '$Needle'" }
}

foreach ($path in @($appPath, $runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-Exists $path
}

Assert-Contains $appPath "name: crossplane-providers-dev"
Assert-Contains $appPath "name: crossplane-platform-apis-dev"
Assert-Contains $appPath "name: crossplane-claims-dev"
Assert-Contains $appPath "argocd.argoproj.io/sync-wave: `"21`""
Assert-Contains $appPath "argocd.argoproj.io/sync-wave: `"22`""
Assert-Contains $appPath "argocd.argoproj.io/sync-wave: `"23`""
Assert-Contains $appPath "include: `"{providers/aws/*.yaml,functions/*.yaml}`""
Assert-Contains $appPath "path: k8s/crossplane/platform-apis"
Assert-Contains $appPath "path: k8s/crossplane/claims/dev/cpemon-api"
Assert-Contains $appPath "ServerSideApply=true"

Assert-Contains $runbookPath "Argo CD Crossplane Wiring Runbook"
Assert-Contains $runbookPath "controller -> providers/functions -> platform APIs -> developer requests"
Assert-Contains $knowledgePath "CCPU-224: Argo CD Wiring for Crossplane"
Assert-Contains $interviewPath "Q29: What did CCPU-224 add?"
Assert-Contains $readmePath "Argo CD Crossplane Wiring Runbook"
Assert-Contains $makefilePath "argocd-crossplane-wiring-check"

Write-Host "Argo CD Crossplane wiring validation passed."
