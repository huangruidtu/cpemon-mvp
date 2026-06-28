# Release Flow with Helm, Kafka, Argo CD, and Argo Rollouts

## Goal

Show how a CPEmon change moves from code to observable platform behavior.

## Flow

```text
developer change
  -> Go tests
  -> Docker image build
  -> Helm values/chart change
  -> Git commit
  -> Argo CD sync
  -> Argo Rollouts canary
  -> Prometheus AnalysisTemplate
  -> promote or abort
```

## Kafka Event Flow

```text
GenieACS / CPE event
  -> acs-ingest
  -> Kafka topic
  -> cpemon-writer consumer group
  -> MySQL read/write model
  -> cpemon-api
  -> dashboard/API response
```

## Validation Commands

```powershell
go test ./...
make helm-cpemon-validate
make kafka-architecture-docs-check
make acs-ingest-kafka-producer-validation-check
make cpemon-writer-kafka-to-db-validation-check
```

## Canary Release

Argo Rollouts introduces progressive delivery for `cpemon-api`.

Success path:

```text
new version receives partial traffic
Prometheus checks HTTP 5xx and latency
analysis succeeds
rollout promotes
```

Failure path:

```text
new version receives partial traffic
Prometheus analysis fails
rollout aborts
stable version remains serving
```

## Interview Framing

The story is not only "I used Argo CD." The stronger answer is:

```text
I connected packaging, GitOps, event-driven processing, canary release, and
observability so application changes could be reviewed, reconciled, measured,
and rolled back using platform signals.
```
