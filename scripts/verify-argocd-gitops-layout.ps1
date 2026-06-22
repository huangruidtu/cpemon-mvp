$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$paths = @(
  "k8s/gitops/README.md",
  "k8s/gitops/dev/README.md",
  "k8s/gitops/dev/applications/README.md",
  "ops/runbooks/argocd-gitops-layout.md",
  "docs/knowledge/argocd-gitops-deployment.md",
  "docs/knowledge/interview/story-17-argocd-gitops-deployment.md"
)

foreach ($path in $paths) {
  if (-not (Test-Path (Join-Path $root $path))) {
    throw "Missing expected Argo CD GitOps layout artifact: $path"
  }
}

$layoutText = Get-Content (Join-Path $root "k8s/gitops/README.md") -Raw
foreach ($snippet in @(
  "k8s/addons/argocd",
  "k8s/gitops",
  "dev",
  "applications",
  "App-Of-Apps Decision",
  "plain Argo CD",
  "deploy/helm/cpemon",
  "k8s/addons/kafka/values.yaml"
)) {
  if ($layoutText -notmatch [regex]::Escape($snippet)) {
    throw "GitOps layout README is missing expected content: $snippet"
  }
}

$appsText = Get-Content (Join-Path $root "k8s/gitops/dev/applications/README.md") -Raw
foreach ($snippet in @(
  "cpemon-dev",
  "kafka-dev",
  "monitoring-dev",
  "external-secrets-dev",
  "policy-security-dev",
  "app-of-apps"
)) {
  if ($appsText -notmatch [regex]::Escape($snippet)) {
    throw "Dev applications README is missing expected content: $snippet"
  }
}

$runbookText = Get-Content (Join-Path $root "ops/runbooks/argocd-gitops-layout.md") -Raw
foreach ($snippet in @(
  "Directory Boundaries",
  "App-Of-Apps Decision",
  "k8s/gitops/dev/applications",
  "scripts/verify-argocd-gitops-layout.ps1",
  "Interview Explanation"
)) {
  if ($runbookText -notmatch [regex]::Escape($snippet)) {
    throw "GitOps layout runbook is missing expected content: $snippet"
  }
}

$knowledgeText = Get-Content (Join-Path $root "docs/knowledge/argocd-gitops-deployment.md") -Raw
foreach ($snippet in @(
  "CCPU-175: Define GitOps Repository Layout",
  "bootstrap",
  "Application manifests",
  "app-of-apps",
  "plain Application"
)) {
  if ($knowledgeText -notmatch [regex]::Escape($snippet)) {
    throw "Argo CD knowledge notes are missing expected layout content: $snippet"
  }
}

$interviewText = Get-Content (Join-Path $root "docs/knowledge/interview/story-17-argocd-gitops-deployment.md") -Raw
foreach ($snippet in @(
  "Why define a GitOps layout before writing Applications?",
  "Why not start with app-of-apps?",
  "What is the boundary between bootstrap and applications?"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Argo CD interview notes are missing expected layout content: $snippet"
  }
}

Write-Host "Argo CD GitOps layout validation passed."
