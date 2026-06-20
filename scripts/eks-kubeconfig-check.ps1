param(
    [string]$ClusterName = "cpemon-dev",
    [string]$Region = "eu-north-1",
    [string]$Profile = "cpemon-terraform",
    [string]$Alias = "cpemon-dev",
    [switch]$WriteKubeconfig
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Run-Step {
    param(
        [string]$Title,
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "== $Title =="
    & $Command
}

Require-Command "aws"

if ($WriteKubeconfig) {
    Require-Command "kubectl"
}

Run-Step "AWS caller identity" {
    aws sts get-caller-identity `
        --profile $Profile `
        --output json
}

Run-Step "EKS cluster status" {
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $script:ClusterDescriptionJson = aws eks describe-cluster `
        --name $ClusterName `
        --region $Region `
        --profile $Profile `
        --output json 2>&1
    $describeClusterExitCode = $LASTEXITCODE
    $ErrorActionPreference = $oldErrorActionPreference

    if ($describeClusterExitCode -ne 0) {
        throw "Unable to describe EKS cluster '$ClusterName' in region '$Region' with profile '$Profile'. AWS CLI output: $script:ClusterDescriptionJson"
    }

    $cluster = ($script:ClusterDescriptionJson | ConvertFrom-Json).cluster
    $cluster | Select-Object name, status, endpoint, version, arn | Format-Table -AutoSize
}

$clusterStatus = (($script:ClusterDescriptionJson | ConvertFrom-Json).cluster).status

if ($clusterStatus -ne "ACTIVE") {
    throw "Cluster '$ClusterName' is '$clusterStatus', not ACTIVE. Wait until EKS reports ACTIVE before generating kubeconfig."
}

if ($WriteKubeconfig) {
    Run-Step "Write kubeconfig context" {
        aws eks update-kubeconfig `
            --region $Region `
            --name $ClusterName `
            --profile $Profile `
            --alias $Alias
    }
}
else {
    Run-Step "Preview kubeconfig context without writing" {
        aws eks update-kubeconfig `
            --region $Region `
            --name $ClusterName `
            --profile $Profile `
            --alias $Alias `
            --dry-run
    }

    Write-Host ""
    Write-Host "Dry run complete. Re-run with -WriteKubeconfig after you are ready to update your local kubeconfig."
    Write-Host "Note: -WriteKubeconfig also requires kubectl to be installed and available in PATH."
    exit 0
}

Run-Step "Current kubectl context" {
    kubectl config current-context
}

Run-Step "Kubernetes API reachability" {
    kubectl cluster-info
}

Run-Step "Namespaces" {
    kubectl get namespaces
}

Run-Step "Nodes" {
    kubectl get nodes -o wide
}

Write-Host ""
Write-Host "EKS kubeconfig and kubectl access check completed."
