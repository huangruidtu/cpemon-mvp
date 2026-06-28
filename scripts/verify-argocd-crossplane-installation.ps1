$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/crossplane-dev.yaml"
$projectPath = Join-Path $root "k8s/addons/argocd/projects/cpemon-project.yaml"
$valuesPath = Join-Path $root "k8s/addons/crossplane/values.yaml"
$namespacePath = Join-Path $root "k8s/base/namespaces.yaml"
$runbookPath = Join-Path $root "ops/runbooks/argocd-crossplane-installation.md"
$knowledgePath = Join-Path $root "docs/knowledge/crossplane-developer-self-service.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-21-crossplane-developer-self-service.md"
$readmePath = Join-Path $root "docs/knowledge/README.md"
$makefilePath = Join-Path $root "Makefile"

function Assert-File {
    param([string] $Path)
    if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
}

function Assert-Contains {
    param([string] $Path, [string] $Needle)
    $content = Get-Content -Raw $Path
    if ($content -notlike "*$Needle*") { throw "Expected '$Path' to contain '$Needle'" }
}

foreach ($path in @($applicationPath, $projectPath, $valuesPath, $namespacePath, $runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-File $path
}

Assert-Contains $applicationPath "kind: Application"
Assert-Contains $applicationPath "name: crossplane-dev"
Assert-Contains $applicationPath "repoURL: https://charts.crossplane.io/stable"
Assert-Contains $applicationPath "chart: crossplane"
Assert-Contains $applicationPath "targetRevision: 2.3.2"
Assert-Contains $applicationPath '$values/k8s/addons/crossplane/values.yaml'
Assert-Contains $applicationPath "namespace: crossplane-system"
Assert-Contains $applicationPath "cpemon.io/sync-policy: manual"
Assert-Contains $valuesPath "resourcesCrossplane:"
Assert-Contains $valuesPath "resourcesRBACManager:"
Assert-Contains $namespacePath "name: crossplane-system"
Assert-Contains $projectPath "https://charts.crossplane.io/stable"
Assert-Contains $projectPath "namespace: crossplane-system"
Assert-Contains $projectPath "pkg.crossplane.io"
Assert-Contains $projectPath "apiextensions.crossplane.io"
Assert-Contains $runbookPath "Application:    crossplane-dev"
Assert-Contains $runbookPath "controller layer"
Assert-Contains $knowledgePath "CCPU-217: Crossplane GitOps Installation"
Assert-Contains $interviewPath "Q8: What did CCPU-217 add?"
Assert-Contains $readmePath "Argo CD Crossplane Installation Runbook"
Assert-Contains $makefilePath "argocd-crossplane-installation-check"

Write-Host "Argo CD Crossplane installation validation passed."
