# CPEmon Cloud Platform Upgrade Jira Task Prompt

Use this prompt when turning a CPEmon Cloud Platform Upgrade task into a Jira-ready work item and execution comment.

## Input

- Jira key:
- Task title:
- Parent story:
- Repository branch:
- Target files:
- Step 1 scope impact:
- Step 2 boundary impact:

## Jira Description Format

Write the Jira description with these sections:

```markdown
## Goal

State the outcome in one or two sentences.

## Context

Explain the current MVP baseline and why this task belongs to the cloud platform upgrade branch.

## Scope

In scope:

- ...

Out of scope:

- ...

## Tasks in Order

1. Review the current repository state and affected files.
2. Confirm the target scope and boundaries.
3. Update the relevant documentation or configuration.
4. Validate cross-document consistency.
5. Add an execution comment to the Jira task.

## Outputs

- `path/to/output`

## Acceptance Criteria

- ...

## Interview Story

I started by ..., then I ..., and the outcome was ...
```

## Execution Comment Format

After implementation, add a Jira comment with:

```markdown
Execution notes:

- Reviewed:
- Changed:
- Validation:
- Remaining follow-up:
```

## Style Rules

- Keep titles short and action-oriented.
- Use `CCPU-XXX` for Jira issue examples in this project.
- Do not use numeric prefixes such as `001` or `002`.
- Keep Step 1 and Step 2 boundaries explicit.
- Do not reintroduce OpenTelemetry or Backstage into Step 1.
- Use the `cloud-platform-upgrade-*` prefix for new upgrade documents.
- Mention `main` only as the current MVP baseline branch.
- Mention `codex/cpemon-cloud-platform-upgrade` as the upgrade work branch.
