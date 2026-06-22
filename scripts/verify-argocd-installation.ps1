$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$paths = @(
  "k8s/addons/argocd/namespace.yaml",
  "k8s/addons/argocd/README.md",
  "ops/runbooks/argocd-installation.md",
  "docs/knowledge/argocd-gitops-deployment.md",
  "docs/knowledge/interview/story-17-argocd-gitops-deployment.md"
)

foreach ($path in $paths) {
  $fullPath = Join-Path $root $path
  if (-not (Test-Path $fullPath)) {
    throw "Missing expected Argo CD installation artifact: $path"
  }
}

$namespaceText = Get-Content (Join-Path $root "k8s/addons/argocd/namespace.yaml") -Raw
foreach ($snippet in @(
  "kind: Namespace",
  "name: argocd",
  "cpemon.io/layer: delivery",
  "cpemon.io/managed-by: gitops-ready-manifest"
)) {
  if ($namespaceText -notmatch [regex]::Escape($snippet)) {
    throw "Argo CD namespace manifest is missing expected content: $snippet"
  }
}

$runbookText = Get-Content (Join-Path $root "ops/runbooks/argocd-installation.md") -Raw
foreach ($snippet in @(
  "kubectl apply -f k8s/addons/argocd/namespace.yaml",
  "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml",
  "--server-side --force-conflicts",
  "kubectl get pods -n argocd",
  "kubectl -n argocd port-forward svc/argocd-server 8080:443",
  "CLI is useful",
  "Production note",
  "Interview Explanation"
)) {
  if ($runbookText -notmatch [regex]::Escape($snippet)) {
    throw "Argo CD installation runbook is missing expected content: $snippet"
  }
}

$knowledgeText = Get-Content (Join-Path $root "docs/knowledge/argocd-gitops-deployment.md") -Raw
foreach ($snippet in @(
  "CI builds, tests, and publishes images",
  "Git records the desired deployment state",
  "Argo CD reconciles the cluster",
  "CCPU-96: Install Argo CD",
  "Production difference"
)) {
  if ($knowledgeText -notmatch [regex]::Escape($snippet)) {
    throw "Argo CD knowledge notes are missing expected content: $snippet"
  }
}

$interviewText = Get-Content (Join-Path $root "docs/knowledge/interview/story-17-argocd-gitops-deployment.md") -Raw
foreach ($snippet in @(
  "Why introduce Argo CD?",
  "Why install Argo CD after Helm?",
  "Does Argo CD replace GitHub Actions?",
  "stable",
  "drift detection"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Argo CD interview notes are missing expected content: $snippet"
  }
}

Write-Host "Argo CD installation artifact validation passed."
