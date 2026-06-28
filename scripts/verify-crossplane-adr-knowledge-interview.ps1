$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$adrPath = Join-Path $root "ADR/cloud-platform-upgrade-crossplane-developer-self-service.md"
$conceptsPath = Join-Path $root "docs/knowledge/crossplane-concepts.md"
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

foreach ($path in @($adrPath, $conceptsPath, $knowledgePath, $interviewPath, $readmePath, $makefilePath)) {
    Assert-Exists $path
}

Assert-Contains $adrPath "Crossplane Developer Self-Service Platform API"
Assert-Contains $adrPath "Terraform remains the owner of the foundation"
Assert-Contains $adrPath "does not grant developers raw AWS provider access"
Assert-Contains $conceptsPath "ProviderConfig"
Assert-Contains $conceptsPath "CompositeResourceDefinition"
Assert-Contains $conceptsPath "Composition maps the platform API"
Assert-Contains $knowledgePath "CCPU-229: ADR, Concepts, and Interview Narrative"
Assert-Contains $interviewPath "Q43: What did CCPU-229 add?"
Assert-Contains $readmePath "Crossplane Developer Self-Service Platform API ADR"
Assert-Contains $readmePath "Crossplane Concepts for CPEmon"
Assert-Contains $makefilePath "crossplane-adr-knowledge-interview-check"

Write-Host "Crossplane ADR, knowledge, and interview validation passed."
