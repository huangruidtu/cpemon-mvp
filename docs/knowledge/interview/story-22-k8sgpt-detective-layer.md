# Story 22 Interview Q&A: K8sGPT Detective Layer

## Q1: What problem did K8sGPT solve in this project?

It reduced the time from Kubernetes symptom to first troubleshooting hypothesis.
Instead of replacing Prometheus or kubectl, it reads cluster state and explains
likely causes such as image pull errors, missing secrets, failing probes, and
broken service selectors.

## Q2: Why call it a detective layer?

Because it investigates and explains. It does not deploy, roll back, approve,
or remediate resources. The final decision still belongs to the operator.

## Q3: How does it fit with Prometheus and Argo CD?

Prometheus shows metric symptoms, Argo CD shows desired-state drift and app
health, and K8sGPT provides a human-readable hypothesis. A good workflow uses
all three instead of trusting one tool blindly.

## Q4: What was the first operating mode?

CLI-first diagnostics, with an optional GitOps-managed operator template. CLI
is easy to demonstrate locally; the operator shows how a platform team would
standardize the capability.

## Q5: Why avoid automatic remediation?

AI explanations can be wrong or incomplete. Automatic remediation can create a
bigger incident if it changes resources based on an incorrect diagnosis.

## Q6: How did you handle secrets?

The repository contains only a Secret template. Real backend API keys must come
from a secret manager or local cluster secret. Secret values are never committed
to Git.

## Q7: What is the RBAC model?

Read-only access to CPEmon and selected platform namespaces. The initial model
uses get, list, and watch permissions for workload, service, event, and rollout
objects. It avoids write permissions.

The important nuance is that the operator chart itself renders controller RBAC,
so I would review the Helm output before live installation. If the permissions
are too broad for the environment, I would keep CLI-only diagnostics first.

## Q8: What does anonymization protect?

It reduces exposure of names and sensitive context sent to the AI backend. It
does not remove the need for review, because cluster metadata can still be
sensitive.

## Q9: What failure demos were added?

Bad image tag, missing Secret reference, broken Service selector, and failing
readiness probe. These are common Kubernetes failures that are easy to explain
in an interview.

## Q10: How would you validate K8sGPT output?

Compare it with `kubectl describe`, `kubectl get events`, pod logs, service
endpoints, Argo CD health, rollout status, and Prometheus alerts.

## Q11: What would you say if K8sGPT and Prometheus disagree?

Prometheus and Kubernetes evidence win. K8sGPT output is a hypothesis. I would
use it to guide investigation, then verify with primary signals.

## Q12: How does this help developers?

It gives developers a clearer first explanation before they escalate to the
platform team. That reduces back-and-forth during common deployment failures.

## Q13: How does this help platform engineers?

It standardizes the early triage checklist and makes incident handoff cleaner:
symptoms, likely cause, evidence, and next command are easier to collect.

## Q14: What was intentionally deferred?

Alertmanager enrichment, Slack/Jira automation, live EKS backend validation,
and automatic remediation were deferred until the read-only diagnostic workflow
is trusted.

## Q15: What is the best interview framing?

```text
I introduced K8sGPT carefully: read-only, namespace-scoped, GitOps-managed,
secret-safe, and backed by runbooks. The important design choice was treating
AI as an assistant for diagnosis, not as a controller that changes production.
```
