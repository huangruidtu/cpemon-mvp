# CPEmon Cloud Platform Upgrade Learning Contract

The CPEmon Cloud Platform Upgrade is not only an implementation project. It is an interview-driven learning project.

The goal is to migrate CPEmon from a YAML-first/local Kubernetes MVP toward a cloud platform model while building a clear mental model of how infrastructure, delivery, security, observability, and operations are designed, reviewed, validated, and explained.

## Working Agreement

For each meaningful story or subtask, we will produce three things:

- Working project changes.
- A knowledge note that explains the concepts and implementation details.
- Interview Q&A that turns the work into spoken answers.

The code should be useful, but the learning trail is equally important. If a future interviewer asks how CPEmon moved from a local Kubernetes MVP to a cloud platform architecture, the answer should be supported by repository evidence.

## Teaching Standard

Each story or subtask should explain:

- What problem the change solves.
- Why the selected AWS or Terraform resource is needed.
- What each important Terraform block does.
- Which decisions were intentionally deferred to later subtasks.
- What command was used to validate the work.
- What errors or risks to watch for.
- How to explain the change in an interview.

## Student Participation

Codex can do most of the mechanical implementation, but Rui should actively participate in the review checkpoints:

- Read Terraform plans before apply.
- Identify resource types in the plan.
- Ask why a resource exists before accepting it.
- Run selected validation commands locally.
- Practice explaining the migration path in plain language.

## Story And Subtask Pattern

For every story or subtask:

1. Confirm the Jira task boundary.
2. Read the existing Terraform or documentation context.
3. Implement the smallest useful change for that task.
4. Write or update the knowledge note.
5. Write or update the interview Q&A.
6. Run formatting and validation commands.
7. Record any important follow-up for the next subtask.

## Example Migration Areas

This contract applies across the whole upgrade, including:

- AWS EKS provisioning.
- Terraform infrastructure as code.
- ECR and CI image publishing.
- GitHub OIDC and cloud access.
- YAML-to-Helm packaging.
- GitOps with Argo CD.
- Kafka migration from simple queue-table behavior.
- Secret management improvements.
- Observability, cost visibility, security gates, and incident drills.

## Important Rule

Do not hide learning behind automation. If code or configuration changes the platform, the docs should explain why that change exists and how it fits into the migration.
