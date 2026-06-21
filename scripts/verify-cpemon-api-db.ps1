param(
  [string]$Namespace = "cpemon",
  [string]$Deployment = "cpemon-api",
  [string]$SecretName = "cpemon-db",
  [string]$SecretKey = "dsn",
  [int]$RolloutTimeoutSeconds = 120,
  [int]$LogTail = 120
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "== $Message =="
}

function Invoke-Kubectl {
  param([string[]]$KubectlArgs)
  & kubectl @KubectlArgs
}

Write-Step "kubectl client and context"
Invoke-Kubectl @("version", "--client")
Invoke-Kubectl @("config", "current-context")

Write-Step "required Secret shape"
$secretJson = Invoke-Kubectl @("-n", $Namespace, "get", "secret", $SecretName, "-o", "json") | ConvertFrom-Json
$secretKeys = @($secretJson.data.PSObject.Properties.Name)
if ($secretKeys -notcontains $SecretKey) {
  throw "Secret $Namespace/$SecretName exists, but key '$SecretKey' is missing."
}
Write-Host "OK: Secret $Namespace/$SecretName contains key '$SecretKey'. Secret value was not printed."

Write-Step "Deployment DB_DSN secretKeyRef"
$deployJson = Invoke-Kubectl @("-n", $Namespace, "get", "deployment", $Deployment, "-o", "json") | ConvertFrom-Json
$dbEnvRefs = @()
foreach ($container in $deployJson.spec.template.spec.containers) {
  foreach ($env in @($container.env)) {
    if ($env.name -eq "DB_DSN") {
      $dbEnvRefs += [pscustomobject]@{
        Container = $container.name
        SecretName = $env.valueFrom.secretKeyRef.name
        SecretKey = $env.valueFrom.secretKeyRef.key
      }
    }
  }
}

if ($dbEnvRefs.Count -eq 0) {
  throw "Deployment $Namespace/$Deployment does not define DB_DSN."
}

$validRef = $false
foreach ($ref in $dbEnvRefs) {
  Write-Host ("DB_DSN in container {0}: {1}/{2}" -f $ref.Container, $ref.SecretName, $ref.SecretKey)
  if ($ref.SecretName -eq $SecretName -and $ref.SecretKey -eq $SecretKey) {
    $validRef = $true
  }
}

if (-not $validRef) {
  throw "Deployment $Namespace/$Deployment DB_DSN does not point to $SecretName/$SecretKey."
}
Write-Host "OK: DB_DSN points to $SecretName/$SecretKey."

Write-Step "rollout status"
Invoke-Kubectl @("-n", $Namespace, "rollout", "status", "deployment/$Deployment", "--timeout=${RolloutTimeoutSeconds}s")

Write-Step "Pods"
Invoke-Kubectl @("-n", $Namespace, "get", "pods", "-l", "app=$Deployment", "-o", "wide")

Write-Step "recent logs"
$logs = Invoke-Kubectl @("-n", $Namespace, "logs", "deployment/$Deployment", "--tail=$LogTail")
$logs | Select-Object -Last $LogTail

if ($logs -match "failed to initialize database") {
  throw "Recent $Deployment logs contain 'failed to initialize database'."
}

if ($logs -match "database connection established") {
  Write-Host "OK: recent logs include 'database connection established'."
} else {
  Write-Warning "Recent logs did not include the DB success marker. If the pod started before the log tail window, inspect older logs or restart after confirming this is safe."
}

Write-Step "health endpoint through port-forward"
$localPort = 18080
$portForward = Start-Process -FilePath "kubectl" `
  -ArgumentList @("-n", $Namespace, "port-forward", "deployment/$Deployment", "${localPort}:8080") `
  -PassThru -WindowStyle Hidden

try {
  Start-Sleep -Seconds 3
  $health = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$localPort/healthz" -TimeoutSec 10
  if ($health.StatusCode -lt 200 -or $health.StatusCode -ge 300) {
    throw "Health endpoint returned HTTP $($health.StatusCode)."
  }
  Write-Host "OK: /healthz returned HTTP $($health.StatusCode)."
}
finally {
  if ($null -ne $portForward -and -not $portForward.HasExited) {
    Stop-Process -Id $portForward.Id -Force
  }
}

Write-Host ""
Write-Host "PASS: $Deployment DB connection verification completed for namespace $Namespace."
