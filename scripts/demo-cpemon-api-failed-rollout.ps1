param(
    [string] $Namespace = "cpemon",
    [string] $RolloutName = "cpemon-api",
    [switch] $Execute
)

$ErrorActionPreference = "Stop"

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

Write-Host "CPEmon API failed rollout demo"
Write-Host "Mode: $(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })"
Write-Host "Namespace: $Namespace"
Write-Host "Rollout: $RolloutName"

Require-Command "kubectl"

if ($Execute) {
    Run-Step "Check Kubernetes connectivity" "kubectl get namespace $Namespace"
    Run-Step "Check Argo Rollouts plugin" "kubectl argo rollouts version"
}
else {
    Write-Host ""
    Write-Host "Dry-run note: live kubectl commands are printed but not executed."
    Write-Host "Use -Execute only against an isolated dev cluster with a controlled bad canary."
}

Run-Step "Verify starting rollout status" "kubectl argo rollouts get rollout $RolloutName -n $Namespace"
Run-Step "Verify stable and canary endpoints" "kubectl get endpoints $RolloutName-stable $RolloutName-canary -n $Namespace"
Run-Step "Watch failed canary progression" "kubectl argo rollouts get rollout $RolloutName -n $Namespace --watch"
Run-Step "List failed analysis evidence" "kubectl get analysisrun -n $Namespace"
Run-Step "Describe failed analysis evidence" "kubectl describe analysisrun -n $Namespace"
Run-Step "Inspect workloads and services" "kubectl get rs,pods,svc,endpoints -n $Namespace -l app=$RolloutName"
Run-Step "Describe rollout failure state" "kubectl describe rollout $RolloutName -n $Namespace"
Run-Step "Abort unsafe canary" "kubectl argo rollouts abort $RolloutName -n $Namespace"
Run-Step "Watch abort result" "kubectl argo rollouts get rollout $RolloutName -n $Namespace --watch"
Run-Step "Verify stable path after abort" "kubectl get endpoints $RolloutName-stable $RolloutName-canary -n $Namespace"

Write-Host ""
Write-Host "Failed demo evidence to explain:"
Write-Host "- Bad canary did not reach full traffic."
Write-Host "- Failed AnalysisRun or degraded status stopped progression."
Write-Host "- Stable Service remained the safe serving path."
Write-Host "- Abort preserved investigation time before retry, rollback, or fix forward."

