param(
  [string]$Helm = "helm",
  [string]$ChartPath = "deploy/helm/cpemon",
  [string]$ValuesFile = "deploy/helm/cpemon/values-dev.yaml",
  [string]$Namespace = "cpemon",
  [string]$OutputDir = "build/helm"
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "== $Message =="
}

function Require-File {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    throw "Required file not found: $Path"
  }
}

function Count-Kind {
  param(
    [string]$Path,
    [string]$Kind
  )

  $pattern = "^kind:\s*`"?$Kind`"?\s*$"
  return @(Select-String -Path $Path -Pattern $pattern).Count
}

Require-File $ValuesFile
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$defaultRender = Join-Path $OutputDir "cpemon-rendered.yaml"
$esoRender = Join-Path $OutputDir "cpemon-eso-rendered.yaml"

Write-Step "Helm version"
& $Helm version --short

Write-Step "Helm lint"
& $Helm lint $ChartPath -f $ValuesFile

Write-Step "Default render should not include ESO resources"
& $Helm template cpemon $ChartPath -n $Namespace -f $ValuesFile | Set-Content -Path $defaultRender -Encoding utf8
$defaultExternalSecrets = Count-Kind -Path $defaultRender -Kind "ExternalSecret"
$defaultSecretStores = (Count-Kind -Path $defaultRender -Kind "SecretStore") + (Count-Kind -Path $defaultRender -Kind "ClusterSecretStore")

if ($defaultExternalSecrets -ne 0 -or $defaultSecretStores -ne 0) {
  throw "Default render unexpectedly included ESO resources: ExternalSecret=$defaultExternalSecrets SecretStore/ClusterSecretStore=$defaultSecretStores"
}
Write-Host "OK: default render includes no ESO resources."

Write-Step "ESO-enabled render"
& $Helm template cpemon $ChartPath -n $Namespace -f $ValuesFile --set externalSecrets.enabled=true | Set-Content -Path $esoRender -Encoding utf8

$secretStoreCount = Count-Kind -Path $esoRender -Kind "SecretStore"
$clusterSecretStoreCount = Count-Kind -Path $esoRender -Kind "ClusterSecretStore"
$externalSecretCount = Count-Kind -Path $esoRender -Kind "ExternalSecret"

Write-Host "SecretStore count: $secretStoreCount"
Write-Host "ClusterSecretStore count: $clusterSecretStoreCount"
Write-Host "ExternalSecret count: $externalSecretCount"

if (($secretStoreCount + $clusterSecretStoreCount) -ne 1) {
  throw "Expected exactly one SecretStore or ClusterSecretStore, found $($secretStoreCount + $clusterSecretStoreCount)."
}

if ($externalSecretCount -ne 3) {
  throw "Expected exactly three ExternalSecret resources, found $externalSecretCount."
}

Write-Step "Required remote references"
$requiredPatterns = @(
  'key:\s*"cpemon/dev/cpemon-db"',
  'property:\s*"dsn"',
  'key:\s*"cpemon/dev/cpemon-acs-hmac"',
  'property:\s*"hmac-secret"',
  'key:\s*"cpemon/dev/mysql-auth"',
  'property:\s*"mysql-root-password"',
  'property:\s*"mysql-username"',
  'property:\s*"mysql-password"',
  'property:\s*"mysql-database"'
)

foreach ($pattern in $requiredPatterns) {
  if (-not (Select-String -Path $esoRender -Pattern $pattern -Quiet)) {
    throw "ESO render missing required pattern: $pattern"
  }
}
Write-Host "OK: expected remote keys and properties are present."

Write-Step "Secret value leak guard"
$forbiddenPatterns = @(
  '^\s*kind:\s*"?Secret"?\s*$',
  '^\s*stringData:\s*$',
  'root:password@tcp',
  'supersecret',
  'CHANGE_ME',
  'mysql-root-password:\s*["''][^"'']+["'']',
  'hmac-secret:\s*["''][^"'']+["'']',
  'dsn:\s*["''][^"'']+["'']'
)

foreach ($pattern in $forbiddenPatterns) {
  if (Select-String -Path $esoRender -Pattern $pattern -Quiet) {
    throw "ESO render matched forbidden secret-value pattern: $pattern"
  }
}
Write-Host "OK: no obvious secret values or Kubernetes Secret payloads were rendered."

Write-Host ""
Write-Host "PASS: ESO render validation completed. Output: $esoRender"
