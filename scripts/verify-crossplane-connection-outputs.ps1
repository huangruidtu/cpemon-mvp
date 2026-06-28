$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$examplePath = Join-Path $root "k8s/crossplane/consumption/cpemon-api-infra-outputs-example.yaml"
$runbookPath = Join-Path $root "ops/runbooks/crossplane-connection-outputs-and-app-consumption.md"
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

foreach ($path in @($examplePath, $runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-Exists $path
}

Assert-Contains $examplePath "kind: ConfigMap"
Assert-Contains $examplePath "name: cpemon-api-infra-outputs"
Assert-Contains $examplePath "ARTIFACTS_BUCKET_REQUEST: cpemon-api-artifacts"
Assert-Contains $examplePath "kind: Secret"
Assert-Contains $examplePath "Do not commit real Crossplane connection secrets"
Assert-Contains $examplePath "resolved-after-live-crossplane-reconciliation"

Assert-Contains $runbookPath "Crossplane Connection Outputs and App Consumption Runbook"
Assert-Contains $runbookPath "ConfigMap vs Secret"
Assert-Contains $runbookPath "External Secrets Boundary"
Assert-Contains $runbookPath "Live values require Crossplane reconciliation"
Assert-Contains $knowledgePath "CCPU-226: Connection Outputs and Application Consumption"
Assert-Contains $interviewPath "Q34: What did CCPU-226 add?"
Assert-Contains $readmePath "Crossplane Connection Outputs and App Consumption Runbook"
Assert-Contains $makefilePath "crossplane-connection-outputs-check"

Write-Host "Crossplane connection outputs validation passed."
