# Developer Troubleshooting with K8sGPT

## When To Use

Use K8sGPT when a deployment fails and the first Kubernetes symptoms are not
obvious.

Good cases:

* Pod stuck in `ImagePullBackOff`
* Pod stuck in `CreateContainerConfigError`
* Service returns no traffic
* Readiness probe fails
* Rollout cannot progress

## Workflow

```powershell
kubectl get pods -n cpemon
k8sgpt analyze --namespace cpemon --explain
kubectl describe pod -n cpemon <pod>
kubectl logs -n cpemon <pod> --tail=100
```

## Escalation

Escalate to platform when:

* RBAC blocks required evidence.
* The issue involves cluster networking, admission policy, or storage.
* K8sGPT output conflicts with metrics or Kubernetes events.
* The suspected fix changes platform-owned resources.

## Developer Rule

K8sGPT helps you ask better questions. It does not approve production changes.
