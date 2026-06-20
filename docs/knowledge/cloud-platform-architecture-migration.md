# Cloud Platform Architecture Migration

This note captures the reusable architecture lessons from the CPEmon Cloud Platform Upgrade planning work. The concrete project is CPEmon, but the thinking pattern applies to many migrations from a lab MVP to a managed cloud platform.

## Mental Model

The MVP proves the application story.

The platform upgrade proves the operating model.

Those are different goals. A raw Kubernetes YAML MVP can be the right first version because it is easy to inspect and explain. A cloud platform edition needs a stronger model for repeatability, review, deployment, security, cost, and operations.

In one sentence:

> A platform migration should preserve the working application story while gradually replacing manual operations with reviewable, automated, Git-driven platform controls.

## What "Architecture Freeze" Means

An architecture freeze does not mean every detail is final forever.

It means the current implementation phase has enough decisions fixed that the team can start building without constantly reopening the foundation.

For CPEmon Step 1, the freeze answered:

- Which branch carries the current MVP?
- Which branch carries the cloud platform upgrade?
- Which managed Kubernetes platform is the target?
- Which tool owns cloud infrastructure?
- Which tool owns Kubernetes desired-state reconciliation?
- Which packaging boundary replaces raw YAML?
- Which event buffer replaces the MVP queue role?
- Which controls are in scope now, and which are deferred?

This prevents scope drift. It also gives Jira stories a clear boundary: each story should implement one platform capability and one validation path.

## MVP vs Platform Upgrade

The current MVP is valuable because it is concrete:

- `acs-ingest`, `cpemon-api`, and `cpemon-writer` are real services.
- Kubernetes Deployments, Services, Ingress, PDBs, NetworkPolicies, monitoring, logging, and backups are visible in raw YAML.
- MySQL queue tables show a simple durable buffering pattern.
- Scripts demonstrate smoke tests, backlog behavior, and backup/restore.

The platform upgrade does not erase that story. It adds a production-style operating model around it:

- Terraform makes cloud infrastructure reviewable.
- EKS provides a managed Kubernetes target.
- ECR stores traceable application images.
- GitHub OIDC removes long-lived AWS keys from CI.
- Helm packages applications and platform components.
- Argo CD reconciles the cluster from Git.
- Kafka becomes the durable event buffer.
- Argo Rollouts and Prometheus support progressive delivery.
- External Secrets Operator moves runtime secrets out of raw manifests.
- Trivy, Kyverno, kubeconform, kube-linter, and Terraform plan checks become quality gates.
- OpenCost and Renovate add cost and maintenance visibility.

## Why Raw YAML Was Right First

Raw YAML is not "bad." It is often the best first teaching surface.

It makes core Kubernetes objects visible:

- What is a Deployment?
- What labels connect a Service to Pods?
- Where are probes and resource requests configured?
- How does Ingress route traffic?
- What does a NetworkPolicy allow or deny?

The limitation is not readability. The limitation is operational scale.

As environments multiply, raw YAML becomes repetitive. Manual `kubectl apply` creates drift risk. Secrets and image tags become harder to manage. Reviewers cannot easily see a standardized promotion path from PR to running workload.

The migration lesson is:

> Start with explicit YAML to learn the system, then introduce packaging and GitOps when repeatability, promotion, and drift control become more important.

## Why GitOps Changes the Operating Model

Manual deployment asks:

```text
What did someone apply to the cluster?
```

GitOps asks:

```text
What does Git say the cluster should look like, and has the reconciler applied it?
```

That is a different control model.

With Argo CD or a similar GitOps controller:

- Git becomes the desired state.
- Pull requests become the review point.
- The cluster is continuously compared with Git.
- Manual cluster changes become drift.
- Rollback can be expressed as a Git change.

This is why GitOps is not just another deployment tool. It is a shift from manual imperative changes to declarative reconciliation.

## Why Helm Appears Before GitOps Scales

Raw YAML can be applied by GitOps, but packaging becomes important when the project needs:

- Environment-specific values.
- Reusable service templates.
- Consistent labels, probes, ports, resources, and annotations.
- A clear application boundary.
- Rendered manifest validation in CI.

Helm is the packaging layer. Argo CD is the reconciliation layer.

The separation matters:

```text
Helm:
  renders Kubernetes manifests from charts and values

Argo CD:
  watches Git and reconciles the cluster to the rendered desired state
```

## Why Kafka Replaces the Queue Role, Not MySQL

In the MVP, MySQL queue tables are a simple durable buffer between ingest and writer services. That is acceptable for a small demo, but it is not the strongest long-term event buffer.

Kafka is introduced for the event stream role:

- Retention and replay.
- Partitions and consumer scaling.
- Consumer lag visibility.
- Durable event fan-out.
- Better fit for high-volume ingest patterns.

MySQL can still remain the business data store.

The migration principle is:

> Replace each component's role deliberately. Kafka replaces the queue/buffer role; it does not automatically replace the relational business database.

## Scope Control: Step 1 vs Step 2

A common migration failure is to turn every attractive platform tool into "Step 1."

CPEmon avoids that by separating:

Step 1:

- EKS baseline.
- Terraform foundation.
- ECR and GitHub OIDC.
- Helm packaging.
- Argo CD GitOps.
- Kafka baseline.
- External Secrets.
- CI/security gates.
- Cost visibility.
- Developer golden path.

Step 2:

- Crossplane or another platform resource control plane.
- k8sGPT-assisted operational insight.
- Broader self-service platform ideas.

The lesson is:

> A good roadmap says "not yet" as clearly as it says "yes."

## Migration Guardrails

Useful guardrails for any platform migration:

- Do not remove the working MVP story while the upgrade is still being built.
- Keep each story small enough to review independently.
- Tie each story to a validation path.
- Avoid mixing foundation work with future platform API or portal work.
- Update roadmap, ADRs, Jira, and README links together when boundaries change.
- Preserve application behavior while changing the platform layer around it.

## Interview-Ready Summary

> The original CPEmon MVP used raw Kubernetes YAML because the first goal was clarity: reviewers could inspect every Deployment, Service, Ingress, NetworkPolicy, and operational script directly. The cloud platform upgrade changes the goal from a lab demo to a repeatable operating model. Step 1 introduces Terraform for infrastructure, EKS as the managed Kubernetes target, Helm for packaging, Argo CD for GitOps reconciliation, ECR and GitHub OIDC for secure image publishing, and Kafka for durable event buffering. The important migration principle is to preserve the working application story while gradually replacing manual operations with reviewable, Git-driven platform controls.

## Questions to Ask in Future Architecture Work

- What is the current MVP proving?
- What operating risk appears when this grows beyond one environment?
- Which tool owns infrastructure?
- Which tool owns application desired state?
- Where is the packaging boundary?
- Where is the release promotion boundary?
- How are secrets delivered?
- How are image tags connected to running workloads?
- Which checks must run before merge?
- Which checks can be deferred without weakening the current story?
- What is explicitly out of scope for this step?
