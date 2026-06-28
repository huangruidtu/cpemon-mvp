# K8sGPT Detective Layer Manifests

This folder contains the CPEmon K8sGPT configuration layer.

The operator installation itself is managed by:

```text
k8s/gitops/dev/applications/k8sgpt-dev.yaml
```

This folder owns the post-install resources:

```text
k8sgpt-secret.tmpl.yaml        secret template only; never commit real API keys
k8sgpt-cpemon.yaml             K8sGPT custom resource for CPEmon diagnostics
rbac/namespace-readers.yaml    explicit read-only scope for CPEmon namespaces
```

The starting model is intentionally conservative:

* K8sGPT can explain and summarize findings.
* K8sGPT must not automatically remediate workloads.
* Real API tokens stay outside Git.
* Live backend validation is separate from offline manifest validation.
