$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$adrPath = Join-Path $root "ADR/cloud-platform-upgrade-crossplane-terraform-boundary.md"
$runbookPath = Join-Path $root "ops/runbooks/crossplane-terraform-boundary.md"
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

foreach ($path in @($adrPath, $runbookPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-File $path
}

Assert-Contains $adrPath "Terraform remains the owner of foundational infrastructure"
Assert-Contains $adrPath "Crossplane owns selected application-level self-service resources"
Assert-Contains $adrPath "developer claim YAML -> Argo CD -> Crossplane claim"
Assert-Contains $runbookPath "Terraform  -> platform foundation"
Assert-Contains $runbookPath "Crossplane -> application-level self-service resources"
Assert-Contains $runbookPath "Live Validation Boundary"
Assert-Contains $knowledgePath "CCPU-216: Terraform and Crossplane Ownership Boundary"
Assert-Contains $knowledgePath "Terraform = build the platform"
Assert-Contains $interviewPath "Q2: What did CCPU-216 add?"
Assert-Contains $readmePath "Crossplane Developer Self-Service Infrastructure Provisioning"
Assert-Contains $readmePath "Crossplane and Terraform Boundary Runbook"
Assert-Contains $readmePath "Terraform and Crossplane Ownership Boundary ADR"
Assert-Contains $makefilePath "crossplane-terraform-boundary-check"

Write-Host "Crossplane Terraform boundary validation passed."
