$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$policyPath = Join-Path $root "k8s/policies/kyverno/baseline/disallow-latest-image-tag.yaml"
$policyReadmePath = Join-Path $root "k8s/policies/kyverno/README.md"
$runbookPath = Join-Path $root "ops/runbooks/kyverno-image-tag-policy.md"
$knowledgePath = Join-Path $root "docs/knowledge/platform-governance-cost-autoscaling.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-20-platform-governance-cost-autoscaling.md"

function Assert-File {
    param([string] $Path)
    if (-not (Test-Path $Path)) {
        throw "Missing required file: $Path"
    }
}

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

foreach ($path in @($policyPath, $policyReadmePath, $runbookPath, $knowledgePath, $interviewPath)) {
    Assert-File $path
}

Assert-Contains $policyPath "apiVersion: kyverno.io/v1"
Assert-Contains $policyPath "kind: ClusterPolicy"
Assert-Contains $policyPath "name: cpemon-disallow-latest-image-tag"
Assert-Contains $policyPath "validationFailureAction: Enforce"
Assert-Contains $policyPath "background: true"
Assert-Contains $policyPath "namespaces:"
Assert-Contains $policyPath "- cpemon"
Assert-Contains $policyPath "request.object.spec.containers"
Assert-Contains $policyPath "regex_match('^.*:latest$', element.image)"
Assert-Contains $policyPath "value: true"

Assert-Contains $policyReadmePath "disallow-latest-image-tag.yaml"
Assert-Contains $runbookPath "GitOps reproducibility"
Assert-Contains $runbookPath "busybox:latest"
Assert-Contains $runbookPath "busybox:1.36"
Assert-Contains $knowledgePath "CCPU-202: Image Tag Policy"
Assert-Contains $interviewPath "Q17: What did CCPU-202 add?"

Write-Host "Kyverno image tag policy validation passed."
