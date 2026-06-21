$ErrorActionPreference = "Stop"

$notes = "docs/knowledge/interview/cpemon-writer-kafka-consumer-learning-notes.md"
$story = "docs/knowledge/interview/story-16-cpemon-writer-kafka-consumer-refactor.md"
$readme = "docs/knowledge/interview/README.md"
$knowledgeReadme = "docs/knowledge/README.md"

foreach ($path in @($notes, $story, $readme, $knowledgeReadme)) {
  if (-not (Test-Path $path)) {
    throw "Missing expected writer Kafka consumer learning artifact: $path"
  }
}

$notesText = Get-Content $notes -Raw
foreach ($snippet in @(
  "60-Second Story",
  "One-Page Review",
  "Mental Model",
  "Key Concepts",
  "Strong Q&A",
  "Producer Versus Consumer Reliability",
  "Debug Flow",
  "Tradeoffs",
  "STAR Story",
  "Follow-Up Questions To Practice",
  "Resume Bullet",
  "EventConsumer",
  "KAFKA_CONSUMER_ENABLED",
  "KAFKA_CONSUMER_GROUP_ID",
  "cpemon.device.heartbeat.v1",
  "cpemon.wan.status.v1",
  "cpemon.deadletter.v1",
  "at-least-once",
  "idempotent",
  "dead-letter",
  "consumer group",
  "offset",
  "lag",
  "structured logs",
  "commit_error"
)) {
  if ($notesText -notmatch [regex]::Escape($snippet)) {
    throw "Writer Kafka consumer learning notes are missing expected content: $snippet"
  }
}

$storyText = Get-Content $story -Raw
foreach ($snippet in @(
  "Story 16: cpemon-writer Kafka Consumer Refactor",
  "Interview Narrative",
  "What problem did this story solve?",
  "Why start with an",
  "What delivery guarantee does this design target?",
  "Why add a dead-letter topic?",
  "How would you debug",
  "How would you explain this as a STAR story?",
  "Resume Version",
  "Feature flag",
  "consumer group",
  "idempotent MySQL",
  "low-cardinality"
)) {
  if ($storyText -notmatch [regex]::Escape($snippet)) {
    throw "Writer Kafka consumer interview Q&A is missing expected content: $snippet"
  }
}

$readmeText = Get-Content $readme -Raw
foreach ($snippet in @(
  "Story 16: cpemon-writer Kafka Consumer Refactor",
  "cpemon-writer Kafka Consumer Learning Notes",
  "retry, dead-letter publishing, lag metrics"
)) {
  if ($readmeText -notmatch [regex]::Escape($snippet)) {
    throw "Interview README is missing expected writer Kafka consumer reference: $snippet"
  }
}

$knowledgeText = Get-Content $knowledgeReadme -Raw
foreach ($snippet in @(
  "cpemon-writer Kafka Consumer Interview Q&A",
  "cpemon-writer Kafka Consumer Learning Notes"
)) {
  if ($knowledgeText -notmatch [regex]::Escape($snippet)) {
    throw "Knowledge README is missing expected writer Kafka consumer learning reference: $snippet"
  }
}

Write-Host "cpemon-writer Kafka consumer learning notes validation passed."
