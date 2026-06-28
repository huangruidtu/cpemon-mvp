$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$xrdPath = Join-Path $root "k8s/crossplane/platform-apis/ecr/xrd.yaml"
$compositionPath = Join-Path $root "k8s/crossplane/platform-apis/ecr/composition.yaml"
$claimPath = Join-Path $root "k8s/crossplane/claims/dev/cpemon-api/ecr-image-repository.yaml"
$runbookPath = Join-Path $root "ops/runbooks/crossplane-ecr-repository-platform-api.md"
$knowledgePath = Join-Path $root "docs/knowledge/crossplane-developer-self-service.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-21-crossplane-developer-self-service.md"
$readmePath = Join-Path $root "docs/knowledge/README.md"
$makefilePath = Join-Path $root "Makefile"

function Assert-Exists {
    param([string]$Path)
    if (!(Test-Path $Path)) { throw "Expected file to exist: $Path" }
}

function Assert-Contains {
    param([string]$Path, [string]$Needle)
    $content = Get-Content $Path -Raw
    if ($content -notlike "*$Needle*") { throw "Expected '$Path' to contain '$Needle'" }
}

foreach ($path in @($xrdPath, $compositionPath, $claimPath, $runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-Exists $path
}

Assert-Contains $xrdPath "kind: XCPemonECRRepository"
Assert-Contains $xrdPath "imageTagMutability"
Assert-Contains $xrdPath "IMMUTABLE"
Assert-Contains $xrdPath "scanOnPush"

Assert-Contains $compositionPath "apiVersion: ecr.aws.m.upbound.io/v1beta1"
Assert-Contains $compositionPath "kind: Repository"
Assert-Contains $compositionPath "imageScanningConfiguration"
Assert-Contains $compositionPath "name: aws-dev-irsa"
Assert-Contains $compositionPath "crossplane.io/external-name"

Assert-Contains $claimPath "kind: XCPemonECRRepository"
Assert-Contains $claimPath "repositoryNameSuffix: cpemon-api"
Assert-Contains $claimPath "imageTagMutability: IMMUTABLE"
Assert-Contains $claimPath "scanOnPush: true"

Assert-Contains $runbookPath "Crossplane ECR Repository Platform API Runbook"
Assert-Contains $knowledgePath "CCPU-222: Optional ECR Repository Self-Service Extension"
Assert-Contains $interviewPath "Q23: What did CCPU-222 add?"
Assert-Contains $readmePath "Crossplane ECR Repository Platform API Runbook"
Assert-Contains $makefilePath "crossplane-ecr-repository-platform-api-check"

Write-Host "Crossplane ECR repository platform API validation passed."
