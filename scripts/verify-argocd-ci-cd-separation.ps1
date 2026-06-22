$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runbookPath = Join-Path $root "ops/runbooks/argocd-ci-cd-separation.md"
$knowledgePath = Join-Path $root "docs/knowledge/argocd-gitops-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-17-argocd-gitops-deployment.md"
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/cpemon-dev.yaml"

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

foreach ($path in @($runbookPath, $knowledgePath, $interviewPath, $applicationPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing required CI/CD separation file: $path"
    }
}

Assert-Contains $runbookPath "GitHub Actions -> test/build/publish image"
Assert-Contains $runbookPath "Argo CD does not build CPEmon images"
Assert-Contains $runbookPath "CI Responsibilities"
Assert-Contains $runbookPath "Git Responsibilities"
Assert-Contains $runbookPath "Argo CD Responsibilities"
Assert-Contains $runbookPath "Promotion Flow"
Assert-Contains $runbookPath "Rollback Boundary"
Assert-Contains $knowledgePath "CCPU-103: Document CI/CD Separation"
Assert-Contains $interviewPath "Q61: What did CCPU-103 add?"
Assert-Contains $applicationPath "path: deploy/helm/cpemon"
Assert-Contains $applicationPath "values-dev.yaml"

Assert-Contains $runbookPath "The important interview point is that Argo CD does not build CPEmon images."
Assert-Contains $interviewPath "Argo CD is not the build system."

Write-Host "Argo CD CI/CD separation documentation passed."
