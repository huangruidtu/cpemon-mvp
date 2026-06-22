$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$policyPath = Join-Path $root "k8s/policies/kyverno/baseline/require-container-resources.yaml"
$policyReadmePath = Join-Path $root "k8s/policies/kyverno/README.md"
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/kyverno-policies-dev.yaml"
$projectPath = Join-Path $root "k8s/addons/argocd/projects/cpemon-project.yaml"
$runbookPath = Join-Path $root "ops/runbooks/kyverno-resource-policy.md"
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

foreach ($path in @($policyPath, $policyReadmePath, $applicationPath, $projectPath, $runbookPath, $knowledgePath, $interviewPath)) {
    Assert-File $path
}

Assert-Contains $policyPath "apiVersion: kyverno.io/v1"
Assert-Contains $policyPath "kind: ClusterPolicy"
Assert-Contains $policyPath "name: cpemon-require-container-resources"
Assert-Contains $policyPath "validationFailureAction: Enforce"
Assert-Contains $policyPath "background: true"
Assert-Contains $policyPath "namespaces:"
Assert-Contains $policyPath "- cpemon"
Assert-Contains $policyPath "request.object.spec.containers"
Assert-Contains $policyPath "element.resources.requests.cpu"
Assert-Contains $policyPath "element.resources.requests.memory"
Assert-Contains $policyPath "element.resources.limits.cpu"
Assert-Contains $policyPath "element.resources.limits.memory"

Assert-Contains $applicationPath "kind: Application"
Assert-Contains $applicationPath "name: kyverno-policies-dev"
Assert-Contains $applicationPath "path: k8s/policies/kyverno"
Assert-Contains $applicationPath "recurse: true"
Assert-Contains $applicationPath "namespace: kyverno"
Assert-Contains $applicationPath "cpemon.io/sync-policy: manual"
Assert-Contains $applicationPath 'cpemon.io/sync-prune: "disabled"'
Assert-Contains $applicationPath 'cpemon.io/sync-self-heal: "disabled"'

Assert-Contains $projectPath "group: kyverno.io"
Assert-Contains $projectPath "kind: ClusterPolicy"
Assert-Contains $runbookPath "admission webhook"
Assert-Contains $runbookPath "HPA CPU utilization math"
Assert-Contains $knowledgePath "CCPU-201: Baseline Resource Policy"
Assert-Contains $interviewPath "Q13: What did CCPU-201 add?"

Write-Host "Kyverno baseline resource policy validation passed."
