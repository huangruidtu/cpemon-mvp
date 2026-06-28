$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$functionPath = Join-Path $root "k8s/crossplane/functions/function-patch-and-transform.yaml"
$xrdPath = Join-Path $root "k8s/crossplane/platform-apis/s3/xrd.yaml"
$compositionPath = Join-Path $root "k8s/crossplane/platform-apis/s3/composition.yaml"
$claimPath = Join-Path $root "k8s/crossplane/claims/dev/cpemon-api/s3-artifacts-bucket.yaml"
$runbookPath = Join-Path $root "ops/runbooks/crossplane-s3-bucket-platform-api.md"
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

foreach ($path in @($functionPath, $xrdPath, $compositionPath, $claimPath, $runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-Exists $path
}

Assert-Contains $functionPath "function-patch-and-transform"
Assert-Contains $functionPath "crossplane-contrib/function-patch-and-transform:v0.8.2"

Assert-Contains $xrdPath "apiVersion: apiextensions.crossplane.io/v2"
Assert-Contains $xrdPath "scope: Namespaced"
Assert-Contains $xrdPath "kind: XCPemonBucket"
Assert-Contains $xrdPath "plural: xcpemonbuckets"
Assert-Contains $xrdPath "defaultCompositionUpdatePolicy: Manual"
Assert-Contains $xrdPath "bucketNameSuffix"
Assert-Contains $xrdPath "eu-north-1"

Assert-Contains $compositionPath "name: xcpemonbucket.aws-s3.standard"
Assert-Contains $compositionPath "mode: Pipeline"
Assert-Contains $compositionPath "function-patch-and-transform"
Assert-Contains $compositionPath "apiVersion: s3.aws.m.upbound.io/v1beta1"
Assert-Contains $compositionPath "kind: Bucket"
Assert-Contains $compositionPath "providerConfigRef:"
Assert-Contains $compositionPath "name: aws-dev-irsa"
Assert-Contains $compositionPath "crossplane.io/external-name"

Assert-Contains $claimPath "kind: XCPemonBucket"
Assert-Contains $claimPath "namespace: cpemon"
Assert-Contains $claimPath "cpemon.io/cost-center: learning"
Assert-Contains $claimPath "bucketNameSuffix: api-artifacts"
Assert-Contains $claimPath "compositionUpdatePolicy: Manual"

Assert-Contains $runbookPath "Crossplane S3 Bucket Platform API Runbook"
Assert-Contains $runbookPath "namespaced composite resource rather than the older v1 claim object"
Assert-Contains $knowledgePath "CCPU-220: S3 Bucket XRD, Composition, and Developer Request"
Assert-Contains $interviewPath "Q17: What did CCPU-220 add?"
Assert-Contains $readmePath "Crossplane S3 Bucket Platform API Runbook"
Assert-Contains $makefilePath "crossplane-s3-bucket-platform-api-check"

Write-Host "Crossplane S3 bucket platform API validation passed."
