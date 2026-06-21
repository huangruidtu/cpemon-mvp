$ErrorActionPreference = "Stop"

$files = @{
  Runbook = "ops/runbooks/cpemon-api-kafka-updated-status-validation.md"
  Api = "app/cpemon-api/main.go"
  Model = "app/pkg/model/model.go"
  Knowledge = "docs/knowledge/cpemon-writer-kafka-consumer-refactor.md"
  Interview = "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
  KnowledgeReadme = "docs/knowledge/README.md"
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) {
    throw "Missing expected API Kafka status validation artifact: $path"
  }
}

$runbookText = Get-Content $files.Runbook -Raw
foreach ($snippet in @(
  "Kafka topic -> cpemon-writer -> MySQL cpe_status -> cpemon-api GET /api/cpe/:sn",
  "ops/runbooks/cpemon-writer-kafka-to-db-validation.md",
  "Invoke-RestMethod",
  "http://127.0.0.1:8081/api/cpe/TEST-CPE-KAFKA-DB-001",
  "SELECT sn, last_seen, wan_ip, sw_version",
  "TEST-CPE-KAFKA-DB-001",
  "10.0.0.13",
  "v1.0-demo",
  "Responsibility Split",
  "does not prove live API behavior"
)) {
  if ($runbookText -notmatch [regex]::Escape($snippet)) {
    throw "API Kafka status validation runbook is missing expected content: $snippet"
  }
}

$apiText = Get-Content $files.Api -Raw
foreach ($snippet in @(
  'r.GET("/api/cpe/:sn", handleGetCPE)',
  "FROM cpe_status",
  "sn, last_seen, wan_ip, sw_version, cpu_pct, mem_pct, updated_at",
  "c.JSON(http.StatusOK, status)"
)) {
  if ($apiText -notmatch [regex]::Escape($snippet)) {
    throw "cpemon-api read path is missing expected content: $snippet"
  }
}

$modelText = Get-Content $files.Model -Raw
foreach ($snippet in @(
  "type CPEStatus struct",
  "LastSeen",
  "WANIP",
  "SWVersion"
)) {
  if ($modelText -notmatch [regex]::Escape($snippet)) {
    throw "CPEStatus model is missing expected content: $snippet"
  }
}

$knowledgeText = Get-Content $files.Knowledge -Raw
foreach ($snippet in @(
  "API Verification For Kafka-Updated Status",
  "ops/runbooks/cpemon-api-kafka-updated-status-validation.md",
  "make cpemon-api-kafka-status-validation-check"
)) {
  if ($knowledgeText -notmatch [regex]::Escape($snippet)) {
    throw "Writer consumer knowledge doc is missing expected API validation content: $snippet"
  }
}

$interviewText = Get-Content $files.Interview -Raw
foreach ($snippet in @(
  "How do you prove the API reads Kafka-updated status?",
  "Kafka event, writer success log, MySQL row, API JSON response",
  "GET /api/cpe/:sn"
)) {
  if ($interviewText -notmatch [regex]::Escape($snippet)) {
    throw "Writer consumer interview notes are missing expected API validation content: $snippet"
  }
}

$readmeText = Get-Content $files.KnowledgeReadme -Raw
if ($readmeText -notmatch [regex]::Escape("cpemon-api Kafka-Updated Status Validation")) {
  throw "Knowledge README does not link the cpemon-api Kafka-updated status validation runbook"
}

Write-Host "cpemon-api Kafka-updated status validation path passed."
