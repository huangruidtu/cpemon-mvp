$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/policy-security-dev.yaml"
$policyPath = Join-Path $root "k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml"
$runbookPath = Join-Path $root "ops/runbooks/argocd-policy-security-application.md"
$networkRunbookPath = Join-Path $root "ops/runbooks/eks-networkpolicy-baseline.md"
$knowledgePath = Join-Path $root "docs/knowledge/argocd-gitops-deployment.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-17-argocd-gitops-deployment.md"

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

Assert-File $applicationPath
Assert-File $policyPath
Assert-File $runbookPath
Assert-File $networkRunbookPath
Assert-File $knowledgePath
Assert-File $interviewPath

Assert-Contains $applicationPath "kind: Application"
Assert-Contains $applicationPath "name: policy-security-dev"
Assert-Contains $applicationPath "namespace: argocd"
Assert-Contains $applicationPath "project: cpemon"
Assert-Contains $applicationPath "repoURL: https://github.com/huangruidtu/cpemon-mvp.git"
Assert-Contains $applicationPath "path: k8s/netpol/baseline"
Assert-Contains $applicationPath "namespace: cpemon"
Assert-Contains $applicationPath "CreateNamespace=false"

Assert-Contains $policyPath "kind: NetworkPolicy"
Assert-Contains $policyPath "name: cpemon-default-deny-egress"
Assert-Contains $policyPath "name: cpemon-allow-dns-egress"
Assert-Contains $policyPath "name: cpemon-allow-core-app-egress"
Assert-Contains $runbookPath "Kyverno is deferred"
Assert-Contains $runbookPath "argocd app get policy-security-dev"
Assert-Contains $runbookPath "NetworkPolicy"
Assert-Contains $networkRunbookPath "NetworkPolicy enforcement"
Assert-Contains $knowledgePath "CCPU-177: Create Application Boundary for Policy and Security Add-ons"
Assert-Contains $interviewPath "Q36: What did CCPU-177 add?"

Write-Host "Argo CD policy/security Application validation passed."
