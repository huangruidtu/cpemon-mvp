$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

function Assert-Exists {
    param([string]$Path)
    if (!(Test-Path $Path)) { throw "Expected file to exist: $Path" }
}

function Assert-Contains {
    param([string]$Path, [string]$Needle)
    $content = Get-Content $Path -Raw
    if ($content -notlike "*$Needle*") {
        throw "Expected '$Path' to contain '$Needle'"
    }
}

$files = @(
    "README.md",
    "docs/golden-path/README.md",
    "docs/golden-path/01-local-development.md",
    "docs/golden-path/02-eks-gitops-platform.md",
    "docs/golden-path/03-release-flow.md",
    "docs/golden-path/04-developer-self-service.md",
    "docs/golden-path/05-operational-runbook.md",
    "docs/final-architecture.md",
    "docs/final-demo.md",
    "docs/final-interview-pack.md",
    "docs/final-evidence-matrix.md",
    "docs/final-roadmap.md",
    "catalog-info.yaml",
    "renovate.json",
    "Makefile"
)

foreach ($file in $files) {
    Assert-Exists (Join-Path $root $file)
}

Assert-Contains (Join-Path $root "README.md") "CPEmon Cloud Platform Upgrade"
Assert-Contains (Join-Path $root "README.md") "Golden Path"
Assert-Contains (Join-Path $root "docs/final-architecture.md") "Platform Control Plane"
Assert-Contains (Join-Path $root "docs/final-demo.md") "Fifteen-Minute Demo"
Assert-Contains (Join-Path $root "docs/final-interview-pack.md") "Resume Bullets"
Assert-Contains (Join-Path $root "docs/final-evidence-matrix.md") "K8sGPT detective layer"
Assert-Contains (Join-Path $root "docs/final-roadmap.md") "Closure Checklist"
Assert-Contains (Join-Path $root "catalog-info.yaml") "kind: System"
Assert-Contains (Join-Path $root "renovate.json") "minor and patch dependency updates"
Assert-Contains (Join-Path $root "Makefile") "final-portfolio-check"

Write-Host "Final portfolio validation passed."
