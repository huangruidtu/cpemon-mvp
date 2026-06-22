$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/kyverno-dev.yaml"
$projectPath = Join-Path $root "k8s/addons/argocd/projects/cpemon-project.yaml"
$valuesPath = Join-Path $root "k8s/addons/kyverno/values.yaml"
$runbookPath = Join-Path $root "ops/runbooks/argocd-kyverno-installation.md"
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

foreach ($path in @($applicationPath, $projectPath, $valuesPath, $runbookPath, $knowledgePath, $interviewPath)) {
    Assert-File $path
}

Assert-Contains $applicationPath "kind: Application"
Assert-Contains $applicationPath "name: kyverno-dev"
Assert-Contains $applicationPath "namespace: argocd"
Assert-Contains $applicationPath "project: cpemon"
Assert-Contains $applicationPath "repoURL: https://kyverno.github.io/kyverno/"
Assert-Contains $applicationPath "chart: kyverno"
Assert-Contains $applicationPath "targetRevision: 3.8.1"
Assert-Contains $applicationPath "releaseName: kyverno"
Assert-Contains $applicationPath '$values/k8s/addons/kyverno/values.yaml'
Assert-Contains $applicationPath "namespace: kyverno"
Assert-Contains $applicationPath "CreateNamespace=false"
Assert-Contains $applicationPath "cpemon.io/sync-policy: manual"
Assert-Contains $applicationPath 'cpemon.io/sync-prune: "disabled"'
Assert-Contains $applicationPath 'cpemon.io/sync-self-heal: "disabled"'

Assert-Contains $valuesPath "crds:"
Assert-Contains $valuesPath "install: true"
Assert-Contains $valuesPath "admissionController:"
Assert-Contains $valuesPath "backgroundController:"
Assert-Contains $valuesPath "cleanupController:"
Assert-Contains $valuesPath "reportsController:"

Assert-Contains $projectPath "https://kyverno.github.io/kyverno/"
Assert-Contains $projectPath "namespace: kyverno"
Assert-Contains $projectPath "kind: CustomResourceDefinition"
Assert-Contains $projectPath "kind: ClusterRole"
Assert-Contains $projectPath "kind: ClusterRoleBinding"
Assert-Contains $projectPath "kind: ValidatingWebhookConfiguration"
Assert-Contains $projectPath "kind: MutatingWebhookConfiguration"

Assert-Contains $runbookPath "kyverno-dev"
Assert-Contains $runbookPath "Chart version:  3.8.1"
Assert-Contains $runbookPath "policy-as-code control plane"
Assert-Contains $knowledgePath "CCPU-200: Kyverno Platform Installation"
Assert-Contains $interviewPath "Q9: What did CCPU-200 add?"

Write-Host "Argo CD Kyverno installation validation passed."
