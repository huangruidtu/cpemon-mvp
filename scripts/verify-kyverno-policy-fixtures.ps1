$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$validPath = Join-Path $root "k8s/policies/kyverno/fixtures/valid/cpemon-valid-pod.yaml"
$invalidDir = Join-Path $root "k8s/policies/kyverno/fixtures/invalid"
$runbookPath = Join-Path $root "ops/runbooks/kyverno-policy-fixtures.md"
$knowledgePath = Join-Path $root "docs/knowledge/platform-governance-cost-autoscaling.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-20-platform-governance-cost-autoscaling.md"

function Assert-File {
    param([string] $Path)
    if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
}

function Assert-Contains {
    param([string] $Path, [string] $Needle)
    $content = Get-Content -Raw $Path
    if ($content -notlike "*$Needle*") { throw "Expected '$Path' to contain '$Needle'" }
}

$invalidFiles = @(
    "missing-resources.yaml",
    "latest-image.yaml",
    "missing-labels.yaml",
    "root-container.yaml"
)

Assert-File $validPath
foreach ($file in $invalidFiles) {
    Assert-File (Join-Path $invalidDir $file)
}
foreach ($path in @($runbookPath, $knowledgePath, $interviewPath)) {
    Assert-File $path
}

Assert-Contains $validPath "resources:"
Assert-Contains $validPath "image: busybox:1.36"
Assert-Contains $validPath "app.kubernetes.io/part-of: cpemon-mvp"
Assert-Contains $validPath "runAsNonRoot: true"
Assert-Contains $validPath "allowPrivilegeEscalation: false"

Assert-Contains (Join-Path $invalidDir "missing-resources.yaml") "name: cpemon-invalid-missing-resources"
Assert-Contains (Join-Path $invalidDir "latest-image.yaml") "image: busybox:latest"
Assert-Contains (Join-Path $invalidDir "missing-labels.yaml") "name: cpemon-invalid-missing-labels"
Assert-Contains (Join-Path $invalidDir "root-container.yaml") "runAsNonRoot: false"
Assert-Contains (Join-Path $invalidDir "root-container.yaml") "allowPrivilegeEscalation: true"

Assert-Contains $runbookPath "kubectl get cpol"
Assert-Contains $runbookPath "kubectl get policyreport -A"
Assert-Contains $knowledgePath "CCPU-204: Policy Validation Fixtures"
Assert-Contains $interviewPath "Q24: What did CCPU-204 add?"

Write-Host "Kyverno policy fixtures validation passed."
