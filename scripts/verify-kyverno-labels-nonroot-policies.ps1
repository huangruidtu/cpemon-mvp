$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$labelsPolicyPath = Join-Path $root "k8s/policies/kyverno/baseline/require-standard-labels.yaml"
$nonRootPolicyPath = Join-Path $root "k8s/policies/kyverno/baseline/require-non-root-containers.yaml"
$policyReadmePath = Join-Path $root "k8s/policies/kyverno/README.md"
$runbookPath = Join-Path $root "ops/runbooks/kyverno-labels-nonroot-policies.md"
$valuesPath = Join-Path $root "deploy/helm/cpemon/values.yaml"
$schemaPath = Join-Path $root "deploy/helm/cpemon/values.schema.json"
$workloadsTemplatePath = Join-Path $root "deploy/helm/cpemon/templates/workloads.yaml"
$knowledgePath = Join-Path $root "docs/knowledge/platform-governance-cost-autoscaling.md"
$interviewPath = Join-Path $root "docs/knowledge/interview/story-20-platform-governance-cost-autoscaling.md"

function Assert-File {
    param([string] $Path)
    if (-not (Test-Path $Path)) {
        throw "Missing required file: $Path"
    }
}

function Assert-Contains {
    param(
        [string] $Path,
        [string] $Needle
    )
    $content = Get-Content -Raw $Path
    if ($content -notlike "*$Needle*") {
        throw "Expected '$Path' to contain '$Needle'"
    }
}

foreach ($path in @($labelsPolicyPath, $nonRootPolicyPath, $policyReadmePath, $runbookPath, $valuesPath, $schemaPath, $workloadsTemplatePath, $knowledgePath, $interviewPath)) {
    Assert-File $path
}

Assert-Contains $labelsPolicyPath "name: cpemon-require-standard-labels"
Assert-Contains $labelsPolicyPath "validationFailureAction: Enforce"
Assert-Contains $labelsPolicyPath "app.kubernetes.io/name"
Assert-Contains $labelsPolicyPath "app.kubernetes.io/instance"
Assert-Contains $labelsPolicyPath "app.kubernetes.io/managed-by"
Assert-Contains $labelsPolicyPath "app.kubernetes.io/part-of"
Assert-Contains $labelsPolicyPath "app.kubernetes.io/component"

Assert-Contains $nonRootPolicyPath "name: cpemon-require-non-root-containers"
Assert-Contains $nonRootPolicyPath "validationFailureAction: Enforce"
Assert-Contains $nonRootPolicyPath "element.securityContext.runAsNonRoot"
Assert-Contains $nonRootPolicyPath "element.securityContext.allowPrivilegeEscalation"

Assert-Contains $valuesPath "securityContext:"
Assert-Contains $valuesPath "runAsNonRoot: true"
Assert-Contains $valuesPath "runAsUser: 10001"
Assert-Contains $valuesPath "allowPrivilegeEscalation: false"
Assert-Contains $valuesPath "drop:"
Assert-Contains $valuesPath "- ALL"
Assert-Contains $schemaPath '"securityContext": { "type": "object" }'
Assert-Contains $workloadsTemplatePath "securityContext:"
Assert-Contains $workloadsTemplatePath "Values.defaults.securityContext"

Assert-Contains $policyReadmePath "require-standard-labels.yaml"
Assert-Contains $policyReadmePath "require-non-root-containers.yaml"
Assert-Contains $runbookPath "Exception Strategy"
Assert-Contains $knowledgePath "CCPU-203: Labels and Non-Root Policies"
Assert-Contains $interviewPath "Q20: What did CCPU-203 add?"

Write-Host "Kyverno labels and non-root policy validation passed."
