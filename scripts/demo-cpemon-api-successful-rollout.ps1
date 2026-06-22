param(
    [string] $Namespace = "cpemon",
    [string] $RolloutName = "cpemon-api",
    [string] $ReleaseName = "cpemon",
    [string] $ValuesFile = "deploy/helm/cpemon/values-dev.yaml",
    [switch] $Execute
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$chartPath = Join-Path $root "deploy/helm/cpemon"
$valuesPath = Join-Path $root $ValuesFile

function Require-Command {
    param([string] $Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH."
    }
}

function Run-Step {
    param(
        [string] $Title,
        [string] $Command
    )

    Write-Host ""
    Write-Host "== $Title =="
    Write-Host $Command

    if ($Execute) {
        Invoke-Expression $Command
    }
}

Write-Host "CPEmon API successful rollout demo"
Write-Host "Mode: $(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })"
Write-Host "Namespace: $Namespace"
Write-Host "Rollout: $RolloutName"

Require-Command "helm"
Require-Command "kubectl"

if (-not (Test-Path $valuesPath)) {
    throw "Values file not found: $valuesPath"
}

Run-Step "Render Helm chart contract" "helm template $ReleaseName `"$chartPath`" -n $Namespace -f `"$valuesPath`""

if ($Execute) {
    Run-Step "Check Kubernetes connectivity" "kubectl get namespace $Namespace"
    Run-Step "Check Argo Rollouts plugin" "kubectl argo rollouts version"
}
else {
    Write-Host ""
    Write-Host "Dry-run note: live kubectl commands are printed but not executed."
    Write-Host "Use -Execute only against a dev cluster where the CPEmon chart is installed or synced."
}

Run-Step "Verify starting rollout status" "kubectl argo rollouts get rollout $RolloutName -n $Namespace"
Run-Step "Inspect stable and canary endpoints" "kubectl get endpoints $RolloutName-stable $RolloutName-canary -n $Namespace"
Run-Step "Watch healthy canary progression" "kubectl argo rollouts get rollout $RolloutName -n $Namespace --watch"
Run-Step "Inspect analysis evidence" "kubectl get analysisrun -n $Namespace"
Run-Step "Describe analysis evidence" "kubectl describe analysisrun -n $Namespace"
Run-Step "Promote at the first healthy pause" "kubectl argo rollouts promote $RolloutName -n $Namespace"
Run-Step "Watch second gate" "kubectl argo rollouts get rollout $RolloutName -n $Namespace --watch"
Run-Step "Promote at the second healthy pause" "kubectl argo rollouts promote $RolloutName -n $Namespace"
Run-Step "Verify final healthy rollout" "kubectl argo rollouts get rollout $RolloutName -n $Namespace"
Run-Step "Verify final workload evidence" "kubectl get rs,pods,svc,endpoints,analysisrun -n $Namespace -l app=$RolloutName"

Write-Host ""
Write-Host "Successful demo evidence to explain:"
Write-Host "- Rollout returned to Healthy."
Write-Host "- AnalysisRuns were Successful."
Write-Host "- The new ReplicaSet became stable."
Write-Host "- 5xx and p95 gates passed before each promotion."
