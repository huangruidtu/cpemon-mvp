param(
  [string]$Namespace = "cpemon",
  [string]$Deployment = "cpemon-writer",
  [string]$SecretName = "cpemon-db",
  [string]$SecretKey = "dsn",
  [string]$ConfigMapName = "cpemon-app-config",
  [int]$RolloutTimeoutSeconds = 120,
  [int]$LogTail = 160
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

function Assert-EnvSecretRef {
  param(
    [object]$DeploymentJson,
    [string]$EnvName,
    [string]$ExpectedSecretName,
    [string]$ExpectedSecretKey
  )

  $matches = @()
  foreach ($container in $DeploymentJson.spec.template.spec.containers) {
    foreach ($env in @($container.env)) {
      if ($env.name -eq $EnvName) {
        $matches += [pscustomobject]@{
          Container = $container.name
          SecretName = $env.valueFrom.secretKeyRef.name
          SecretKey = $env.valueFrom.secretKeyRef.key
        }
      }
    }
  }

  if ($matches.Count -eq 0) {
    throw "Deployment $Namespace/$Deployment does not define $EnvName."
  }

  foreach ($match in $matches) {
    Write-Host ("{0} in container {1}: {2}/{3}" -f $EnvName, $match.Container, $match.SecretName, $match.SecretKey)
    if ($match.SecretName -eq $ExpectedSecretName -and $match.SecretKey -eq $ExpectedSecretKey) {
      Write-Host "OK: $EnvName points to $ExpectedSecretName/$ExpectedSecretKey."
      return
    }
  }

  throw "Deployment $Namespace/$Deployment $EnvName does not point to $ExpectedSecretName/$ExpectedSecretKey."
}

function Assert-EnvConfigMapRef {
  param(
    [object]$DeploymentJson,
    [string]$EnvName,
    [string]$ExpectedConfigMapName,
    [string]$ExpectedConfigMapKey
  )

  $matches = @()
  foreach ($container in $DeploymentJson.spec.template.spec.containers) {
    foreach ($env in @($container.env)) {
      if ($env.name -eq $EnvName) {
        $matches += [pscustomobject]@{
          Container = $container.name
          ConfigMapName = $env.valueFrom.configMapKeyRef.name
          ConfigMapKey = $env.valueFrom.configMapKeyRef.key
        }
      }
    }
  }

  if ($matches.Count -eq 0) {
    throw "Deployment $Namespace/$Deployment does not define $EnvName."
  }

  foreach ($match in $matches) {
    Write-Host ("{0} in container {1}: {2}/{3}" -f $EnvName, $match.Container, $match.ConfigMapName, $match.ConfigMapKey)
    if ($match.ConfigMapName -eq $ExpectedConfigMapName -and $match.ConfigMapKey -eq $ExpectedConfigMapKey) {
      Write-Host "OK: $EnvName points to $ExpectedConfigMapName/$ExpectedConfigMapKey."
      return
    }
  }

  throw "Deployment $Namespace/$Deployment $EnvName does not point to $ExpectedConfigMapName/$ExpectedConfigMapKey."
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

Write-Step "required ConfigMap shape"
$configJson = Invoke-Kubectl @("-n", $Namespace, "get", "configmap", $ConfigMapName, "-o", "json") | ConvertFrom-Json
$configKeys = @($configJson.data.PSObject.Properties.Name)
foreach ($requiredKey in @("WORKER_INTERVAL", "BATCH_SIZE", "HTTP_ADDR")) {
  if ($configKeys -notcontains $requiredKey) {
    throw "ConfigMap $Namespace/$ConfigMapName exists, but key '$requiredKey' is missing."
  }
}
Write-Host "OK: ConfigMap $Namespace/$ConfigMapName contains WORKER_INTERVAL, BATCH_SIZE, and HTTP_ADDR."

Write-Step "Deployment env wiring"
$deployJson = Invoke-Kubectl @("-n", $Namespace, "get", "deployment", $Deployment, "-o", "json") | ConvertFrom-Json
Assert-EnvSecretRef -DeploymentJson $deployJson -EnvName "DB_DSN" -ExpectedSecretName $SecretName -ExpectedSecretKey $SecretKey
Assert-EnvConfigMapRef -DeploymentJson $deployJson -EnvName "WORKER_INTERVAL" -ExpectedConfigMapName $ConfigMapName -ExpectedConfigMapKey "WORKER_INTERVAL"
Assert-EnvConfigMapRef -DeploymentJson $deployJson -EnvName "BATCH_SIZE" -ExpectedConfigMapName $ConfigMapName -ExpectedConfigMapKey "BATCH_SIZE"

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

if ($logs -match "cpemon-writer runOnce error") {
  throw "Recent $Deployment logs contain 'cpemon-writer runOnce error'."
}

if ($logs -match "database connection established") {
  Write-Host "OK: recent logs include 'database connection established'."
} else {
  Write-Warning "Recent logs did not include the DB success marker. If the pod started before the log tail window, inspect older logs or restart after confirming this is safe."
}

if ($logs -match "cpemon-writer worker loop started") {
  Write-Host "OK: recent logs include the writer loop startup marker."
} else {
  Write-Warning "Recent logs did not include the writer loop startup marker. Inspect older logs if the pod has been running for a long time."
}

Write-Step "health endpoint through port-forward"
$localPort = 18081
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
Write-Host "PASS: $Deployment DB write-path verification completed for namespace $Namespace."
