$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$claimsReadmePath = Join-Path $root "k8s/crossplane/claims/README.md"
$appReadmePath = Join-Path $root "k8s/crossplane/claims/dev/cpemon-api/README.md"
$kustomizationPath = Join-Path $root "k8s/crossplane/claims/dev/cpemon-api/kustomization.yaml"
$s3Path = Join-Path $root "k8s/crossplane/claims/dev/cpemon-api/s3-artifacts-bucket.yaml"
$dynamoPath = Join-Path $root "k8s/crossplane/claims/dev/cpemon-api/dynamodb-health-table.yaml"
$ecrPath = Join-Path $root "k8s/crossplane/claims/dev/cpemon-api/ecr-image-repository.yaml"
$runbookPath = Join-Path $root "ops/runbooks/crossplane-developer-self-service-requests.md"
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

foreach ($path in @($claimsReadmePath, $appReadmePath, $kustomizationPath, $s3Path, $dynamoPath, $ecrPath, $runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-Exists $path
}

Assert-Contains $claimsReadmePath "Pull Request Workflow"
Assert-Contains $claimsReadmePath "Reviewer Checklist"
Assert-Contains $appReadmePath "cpemon-api Developer Infrastructure Requests"
Assert-Contains $appReadmePath "XCPemonBucket"
Assert-Contains $appReadmePath "XCPemonDynamoTable"
Assert-Contains $appReadmePath "XCPemonECRRepository"
Assert-Contains $kustomizationPath "s3-artifacts-bucket.yaml"
Assert-Contains $kustomizationPath "dynamodb-health-table.yaml"
Assert-Contains $kustomizationPath "ecr-image-repository.yaml"
Assert-Contains $kustomizationPath "cpemon.io/request-type: crossplane-self-service"
Assert-Contains $runbookPath "Crossplane Developer Self-Service Requests Runbook"
Assert-Contains $runbookPath "Developer edits request YAML"
Assert-Contains $knowledgePath "CCPU-223: Developer Self-Service Request Layout"
Assert-Contains $interviewPath "Q26: What did CCPU-223 add?"
Assert-Contains $readmePath "Crossplane Developer Self-Service Requests Runbook"
Assert-Contains $makefilePath "crossplane-developer-requests-check"

Write-Host "Crossplane developer self-service requests validation passed."
