$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

function Assert-Exists {
    param([string]$Path)
    if (!(Test-Path $Path)) { throw "Expected file to exist: $Path" }
}

function Assert-Contains {
    param([string]$Path, [string]$Needle)
    $content = Get-Content $Path -Raw
    if ($content -notlike "*$Needle*") { throw "Expected '$Path' to contain '$Needle'" }
}

$files = @(
    "k8s/base/namespaces.yaml",
    "k8s/addons/k8sgpt/values.yaml",
    "k8s/gitops/dev/applications/k8sgpt-dev.yaml",
    "k8s/gitops/dev/applications/k8sgpt-config-dev.yaml",
    "k8s/k8sgpt/README.md",
    "k8s/k8sgpt/kustomization.yaml",
    "k8s/k8sgpt/k8sgpt-cpemon.yaml",
    "k8s/k8sgpt/k8sgpt-secret.tmpl.yaml",
    "k8s/k8sgpt/rbac/namespace-readers.yaml",
    "ops/demos/k8sgpt/bad-image.yaml",
    "ops/demos/k8sgpt/missing-secret.yaml",
    "ops/demos/k8sgpt/broken-service-selector.yaml",
    "ops/demos/k8sgpt/failing-probe.yaml",
    "ops/runbooks/k8sgpt-cli-diagnostics.md",
    "ops/runbooks/k8sgpt-operator-installation.md",
    "ops/runbooks/k8sgpt-security-rbac-boundary.md",
    "ops/runbooks/k8sgpt-backend-secret-boundary.md",
    "ops/runbooks/k8sgpt-analyzer-scope.md",
    "ops/runbooks/k8sgpt-controlled-failure-demos.md",
    "ops/runbooks/k8sgpt-output-verification.md",
    "ops/runbooks/argocd-k8sgpt-application.md",
    "ops/runbooks/k8sgpt-developer-troubleshooting.md",
    "ops/runbooks/k8sgpt-incident-triage.md",
    "ops/runbooks/k8sgpt-observability-alert-boundary.md",
    "ops/runbooks/k8sgpt-validation.md",
    "ops/runbooks/k8sgpt-story-final-checklist.md",
    "ADR/cloud-platform-upgrade-k8sgpt-detective-layer.md",
    "docs/knowledge/k8sgpt-detective-layer.md",
    "docs/knowledge/interview/story-22-k8sgpt-detective-layer.md",
    "docs/knowledge/README.md",
    "k8s/gitops/dev/applications/README.md",
    "Makefile"
)

foreach ($file in $files) {
    Assert-Exists (Join-Path $root $file)
}

Assert-Contains (Join-Path $root "k8s/base/namespaces.yaml") "k8sgpt-operator-system"
Assert-Contains (Join-Path $root "k8s/addons/k8sgpt/values.yaml") "serviceMonitor"
Assert-Contains (Join-Path $root "k8s/gitops/dev/applications/k8sgpt-dev.yaml") "https://charts.k8sgpt.ai/"
Assert-Contains (Join-Path $root "k8s/gitops/dev/applications/k8sgpt-config-dev.yaml") "path: k8s/k8sgpt"
Assert-Contains (Join-Path $root "k8s/k8sgpt/k8sgpt-cpemon.yaml") "kind: K8sGPT"
Assert-Contains (Join-Path $root "k8s/k8sgpt/k8sgpt-cpemon.yaml") "anonymized: true"
Assert-Contains (Join-Path $root "k8s/k8sgpt/k8sgpt-secret.tmpl.yaml") "REPLACE_WITH_EXTERNAL_SECRET_VALUE"
Assert-Contains (Join-Path $root "k8s/k8sgpt/rbac/namespace-readers.yaml") "get"
Assert-Contains (Join-Path $root "k8s/k8sgpt/rbac/namespace-readers.yaml") "list"
Assert-Contains (Join-Path $root "k8s/k8sgpt/rbac/namespace-readers.yaml") "watch"
Assert-Contains (Join-Path $root "k8s/k8sgpt/rbac/namespace-readers.yaml") "k8sgpt-k8sgpt-operator-controller-manager"
Assert-Contains (Join-Path $root "ops/demos/k8sgpt/bad-image.yaml") "definitely-not-a-real-tag"
Assert-Contains (Join-Path $root "ops/demos/k8sgpt/missing-secret.yaml") "missing-cpemon-database-secret"
Assert-Contains (Join-Path $root "ops/demos/k8sgpt/broken-service-selector.yaml") "does-not-match-any-pod"
Assert-Contains (Join-Path $root "ops/demos/k8sgpt/failing-probe.yaml") "/this-path-does-not-exist"
Assert-Contains (Join-Path $root "ADR/cloud-platform-upgrade-k8sgpt-detective-layer.md") "detective layer"
Assert-Contains (Join-Path $root "docs/knowledge/k8sgpt-detective-layer.md") "CCPU-246"
Assert-Contains (Join-Path $root "docs/knowledge/interview/story-22-k8sgpt-detective-layer.md") "Q15"
Assert-Contains (Join-Path $root "ops/runbooks/k8sgpt-story-final-checklist.md") "Final Interview Summary"
Assert-Contains (Join-Path $root "Makefile") "k8sgpt-detective-layer-check"

Write-Host "K8sGPT detective layer validation passed."
