$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$familyPath = Join-Path $root "k8s/crossplane/providers/aws/provider-family-aws.yaml"
$servicesPath = Join-Path $root "k8s/crossplane/providers/aws/provider-services.yaml"
$providerConfigPath = Join-Path $root "k8s/crossplane/providers/aws/providerconfig.yaml"
$projectPath = Join-Path $root "k8s/addons/argocd/projects/cpemon-project.yaml"
$runbookPath = Join-Path $root "ops/runbooks/crossplane-aws-provider-irsa.md"
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

foreach ($path in @($familyPath, $servicesPath, $providerConfigPath, $projectPath, $runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-File $path
}

Assert-Contains $familyPath "kind: Provider"
Assert-Contains $familyPath "provider-family-aws"
Assert-Contains $familyPath "xpkg.upbound.io/upbound/provider-family-aws:v2.0.0"
Assert-Contains $familyPath "kind: DeploymentRuntimeConfig"
Assert-Contains $familyPath "aws-irsa-runtime"
Assert-Contains $familyPath "eks.amazonaws.com/role-arn"
Assert-Contains $servicesPath "provider-aws-s3"
Assert-Contains $servicesPath "provider-aws-dynamodb"
Assert-Contains $servicesPath "provider-aws-ecr"
Assert-Contains $providerConfigPath "apiVersion: aws.upbound.io/v1beta1"
Assert-Contains $providerConfigPath "kind: ProviderConfig"
Assert-Contains $providerConfigPath "name: aws-dev-irsa"
Assert-Contains $providerConfigPath "source: IRSA"
Assert-Contains $projectPath "DeploymentRuntimeConfig"
Assert-Contains $projectPath "ProviderConfig"
Assert-Contains $runbookPath "Crossplane AWS Provider and IRSA Runbook"
Assert-Contains $runbookPath "Static AWS access keys are intentionally avoided"
Assert-Contains $knowledgePath "CCPU-218: AWS Provider and IRSA Authentication Boundary"
Assert-Contains $interviewPath "Q11: What did CCPU-218 add?"
Assert-Contains $readmePath "Crossplane AWS Provider and IRSA Runbook"
Assert-Contains $makefilePath "crossplane-aws-provider-irsa-check"

Write-Host "Crossplane AWS Provider IRSA validation passed."
