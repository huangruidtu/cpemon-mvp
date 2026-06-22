$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$project = "k8s/addons/argocd/projects/cpemon-project.yaml"
$runbook = "ops/runbooks/argocd-project.md"
$knowledge = "docs/knowledge/argocd-gitops-deployment.md"
$interview = "docs/knowledge/interview/story-17-argocd-gitops-deployment.md"

foreach ($path in @($project, $runbook, $knowledge, $interview)) {
  if (-not (Test-Path (Join-Path $root $path))) {
    throw "Missing expected Argo CD project artifact: $path"
  }
}

$projectText = Get-Content (Join-Path $root $project) -Raw
foreach ($snippet in @(
  "kind: AppProject",
  "name: cpemon",
  "namespace: argocd",
  "https://github.com/huangruidtu/cpemon-mvp.git",
  "namespace: cpemon",
  "namespace: kafka",
  "namespace: monitoring",
  "namespace: security",
  "namespace: platform",
  "orphanedResources",
  "warn: true"
)) {
  if ($projectText -notmatch [regex]::Escape($snippet)) {
    throw "Argo CD AppProject manifest is missing expected content: $snippet"
  }
}

$runbookText = Get-Content (Join-Path $root $runbook) -Raw
foreach ($snippet in @(
  "AppProject",
  "kubectl get appproject cpemon -n argocd",
  "argocd proj get cpemon",
  "Learning Boundary",
  "Production Hardening",
  "repository not permitted",
  "destination not permitted",
  "Interview Explanation"
)) {
  if ($runbookText -notmatch [regex]::Escape($snippet)) {
    throw "Argo CD project runbook is missing expected content: $snippet"
  }
}

$knowledgeText = Get-Content (Join-Path $root $knowledge) -Raw
foreach ($snippet in @(
  "CCPU-97: Create Argo CD Project",
  "AppProject",
  "https://github.com/huangruidtu/cpemon-mvp.git",
  "cpemon",
  "kafka",
  "monitoring",
  "production"
)) {
  if ($knowledgeText -notmatch [regex]::Escape($snippet)) {
    throw "Argo CD knowledge notes are missing expected project content: $snippet"
  }
}

$interviewText = Get-Content (Join-Path $root $interview) -Raw
foreach ($snippet in @(
  "What is an AppProject?",
  "Why not let every Application deploy anywhere?",
  "What did CCPU-97 add?",
  "repository",
  "namespace"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Argo CD interview notes are missing expected project content: $snippet"
  }
}

Write-Host "Argo CD AppProject artifact validation passed."
