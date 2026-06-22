# Story 17: Argo CD GitOps Deployment

Use this page for Story 11 Jira work: Argo CD GitOps Deployment.

## Q1: Why introduce Argo CD?

Manual `kubectl apply` is useful for learning, but it does not give a durable
deployment source of truth. Argo CD makes Git the desired state, watches for
drift, and reconciles Kubernetes resources from the repository.

## Q2: Why install Argo CD after Helm?

Helm defines how the application renders into Kubernetes manifests. Argo CD
needs that packaging boundary so it can reconcile the chart from Git. The order
is easier to explain as:

```text
Terraform creates infrastructure.
Helm packages Kubernetes workloads.
Argo CD reconciles packaged workloads from Git.
```

## Q3: What did CCPU-96 add?

It added the Argo CD installation boundary: the `argocd` namespace manifest,
the learning install command, verification commands, access instructions, and a
runbook that explains what is learning-only versus production-ready.

## Q4: Does Argo CD replace GitHub Actions?

No. GitHub Actions remains CI: test, build, and publish images. Argo CD is CD:
it deploys the desired Kubernetes state from Git.

## Q5: Why is the `stable` upstream install acceptable here?

It is acceptable for the learning environment because it follows the official
quick-start path and keeps the first subtask small. For production, I would pin
an Argo CD version and review the manifests before rollout.

## Q6: What is the first validation after install?

Check the namespace and control-plane pods:

```powershell
kubectl get ns argocd
kubectl get pods -n argocd
kubectl get deploy -n argocd
kubectl get svc -n argocd
```

## Q7: What is the interview-level value of Argo CD?

The value is not just deployment automation. The value is a reviewable desired
state, drift detection, reconciliation, easier rollback, and a clean separation
between image build and cluster deployment.

## Q8: What is an AppProject?

An AppProject is an Argo CD guardrail. It defines which repositories an
Application can read from and which cluster destinations it can deploy to.

## Q9: Why not let every Application deploy anywhere?

That would make the GitOps controller too powerful by default. A project
boundary limits blast radius and makes ownership clearer. In CPEmon, the
learning project allows the repo to deploy only to the namespaces used by the
application and platform add-ons.

## Q10: What did CCPU-97 add?

It added the `cpemon` AppProject manifest, a project runbook, repository and
namespace boundary documentation, and validation that the project remains tied
to the CPEmon source repository.

## Q11: How would you harden the AppProject for production?

I would split projects by environment, restrict cluster-scoped resources,
review allowed repositories, add Argo CD RBAC, and avoid giving a single
learning project broad access to every namespace.
