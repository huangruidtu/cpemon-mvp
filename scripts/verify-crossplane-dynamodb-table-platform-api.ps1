$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$xrdPath = Join-Path $root "k8s/crossplane/platform-apis/dynamodb/xrd.yaml"
$compositionPath = Join-Path $root "k8s/crossplane/platform-apis/dynamodb/composition.yaml"
$claimPath = Join-Path $root "k8s/crossplane/claims/dev/cpemon-api/dynamodb-health-table.yaml"
$runbookPath = Join-Path $root "ops/runbooks/crossplane-dynamodb-table-platform-api.md"
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

Assert-Contains $xrdPath "apiVersion: apiextensions.crossplane.io/v2"
Assert-Contains $xrdPath "kind: XCPemonDynamoTable"
Assert-Contains $xrdPath "partitionKey"
Assert-Contains $xrdPath "PAY_PER_REQUEST"

Assert-Contains $compositionPath "name: xcpemondynamotable.aws-dynamodb.standard"
Assert-Contains $compositionPath "apiVersion: dynamodb.aws.m.upbound.io/v1beta1"
Assert-Contains $compositionPath "kind: Table"
Assert-Contains $compositionPath "providerConfigRef:"
Assert-Contains $compositionPath "name: aws-dev-irsa"
Assert-Contains $compositionPath "hashKey"
Assert-Contains $compositionPath "crossplane.io/external-name"

Assert-Contains $claimPath "kind: XCPemonDynamoTable"
Assert-Contains $claimPath "namespace: cpemon"
Assert-Contains $claimPath "partitionKey: healthId"
Assert-Contains $claimPath "billingMode: PAY_PER_REQUEST"

Assert-Contains $runbookPath "Crossplane DynamoDB Table Platform API Runbook"
Assert-Contains $knowledgePath "CCPU-221: DynamoDB Table XRD, Composition, and Developer Request"
Assert-Contains $interviewPath "Q20: What did CCPU-221 add?"
Assert-Contains $readmePath "Crossplane DynamoDB Table Platform API Runbook"
Assert-Contains $makefilePath "crossplane-dynamodb-table-platform-api-check"

Write-Host "Crossplane DynamoDB table platform API validation passed."
