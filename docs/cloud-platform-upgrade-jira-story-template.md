# CPEmon Jira Story Template

## Story Title

CCPU-XXX: Short action-oriented title

## Story Goal

Describe the platform capability or migration outcome in one or two sentences.

## Context

Explain what exists in the MVP today, what limitation this story addresses, and why this is part of Step 1 rather than Step 2.

## Scope

In scope:

- Item 1
- Item 2
- Item 3

Out of scope:

- Item 1
- Item 2

## Tasks in Order

1. Review the current repository and affected files.
2. Document the current state.
3. Define the target Step 1 behavior.
4. Implement or document the change.
5. Add validation checks.
6. Add or update ADRs if the decision changes architecture.
7. Add an incident drill or operational note.
8. Update README or roadmap links.

## Verification / Validation

- Required file or configuration exists.
- Local validation command passes.
- PR quality gate covers the change where applicable.
- Documentation explains how to operate or troubleshoot the capability.

## Debug / Incident Drill

Describe one realistic failure mode and how to diagnose it.

Examples:

- GitOps drift.
- Failed Terraform plan.
- Failed image scan.
- Rollout analysis failure.
- Kafka consumer lag.
- External secret sync failure.

## Documentation

Update:

- `README.md`
- `docs/cloud-platform-upgrade-step1-architecture.md`
- `docs/cloud-platform-upgrade-roadmap.md`
- `docs/ai/prompts/cloud-platform-upgrade-jira-task.md` if the reusable Jira task workflow changes
- `ADR/` if needed
- Runbooks if operational behavior changes

## Execution Comment

After implementation, add a Jira comment:

```markdown
Execution notes:

- Reviewed:
- Changed:
- Validation:
- Remaining follow-up:
```

## Interview Story

Summarize the story in first person:

I started by ..., then I ..., and the outcome was ...
