$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$applicationPath = Join-Path $root "k8s/gitops/dev/applications/external-secrets-dev.yaml"
$projectPath = Join-Path $root "k8s/addons/argocd/projects/cpemon-project.yaml"
$valuesPath = Join-Path $root "k8s/addons/external-secrets/values.yaml"
$runbookPath = Join-Path $root "ops/runbooks/argocd-external-secrets-application.md"
$adrPath = Join-Path $root "ADR/cloud-platform-upgrade-eso-aws-secrets-manager-kms.md"
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
Assert-File $projectPath
Assert-File $valuesPath
Assert-File $runbookPath
Assert-File $adrPath
Assert-File $knowledgePath
Assert-File $interviewPath

Assert-Contains $applicationPath "kind: Application"
Assert-Contains $applicationPath "name: external-secrets-dev"
Assert-Contains $applicationPath "namespace: argocd"
Assert-Contains $applicationPath "project: cpemon"
Assert-Contains $applicationPath "sources:"
Assert-Contains $applicationPath "repoURL: https://charts.external-secrets.io"
Assert-Contains $applicationPath "chart: external-secrets"
Assert-Contains $applicationPath "targetRevision: 2.6.0"
Assert-Contains $applicationPath "releaseName: external-secrets"
Assert-Contains $applicationPath '$values/k8s/addons/external-secrets/values.yaml'
Assert-Contains $applicationPath "namespace: external-secrets"
Assert-Contains $applicationPath "CreateNamespace=false"

Assert-Contains $valuesPath "installCRDs: true"
Assert-Contains $valuesPath "name: external-secrets"
Assert-Contains $valuesPath "annotations: {}"
Assert-Contains $projectPath "https://charts.external-secrets.io"
Assert-Contains $projectPath "namespace: external-secrets"
Assert-Contains $projectPath "kind: ClusterRole"
Assert-Contains $projectPath "kind: ClusterRoleBinding"
Assert-Contains $projectPath "kind: ValidatingWebhookConfiguration"
Assert-Contains $runbookPath "Git does not own"
Assert-Contains $runbookPath "argocd app get external-secrets-dev"
Assert-Contains $runbookPath "external_secrets_irsa_role_arn"
Assert-Contains $adrPath "AWS Secrets Manager"
Assert-Contains $adrPath "KMS"
Assert-Contains $knowledgePath "CCPU-176: Create Application Boundary for External Secrets"
Assert-Contains $interviewPath "Q31: What did CCPU-176 add?"

Write-Host "Argo CD External Secrets Application validation passed."
