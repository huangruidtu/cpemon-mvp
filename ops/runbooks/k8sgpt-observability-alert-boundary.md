# K8sGPT Observability and Alert Enrichment Boundary

## Current Implementation

K8sGPT is added as a detective layer with CLI and GitOps-managed operator
templates.

It is not yet wired to:

* Alertmanager notifications
* Slack messages
* Jira incident comments
* automated remediation

## Why Defer Alert Enrichment

Alert enrichment is useful only after the team trusts:

* analyzer scope
* privacy controls
* backend cost
* result quality
* runbook verification

## Future Path

1. Keep manual CLI analysis.
2. Add operator-managed results.
3. Add sampled or on-demand alert enrichment.
4. Add human-approved remediation suggestions.
5. Consider automation only for narrow, reversible actions.

## Interview Note

The mature answer is that AI operations should start as decision support. Only
after enough trust and guardrails exist should it influence alert workflows.
