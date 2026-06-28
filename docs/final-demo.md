# Final Demo Script

## Five-Minute Architecture Talk Track

```text
CPEmon started as a Kubernetes monitoring MVP. I upgraded it into an EKS-style
platform: Terraform builds the foundation, Helm packages the app, Argo CD
reconciles desired state, Kafka decouples ingest and writing, Argo Rollouts
adds canary safety, Prometheus/Grafana observe the system, Kyverno and OpenCost
add governance and cost visibility, Crossplane exposes selected self-service
resources, and K8sGPT provides a read-only detective layer.
```

## Fifteen-Minute Demo

### 1. Repo Front Door

Show:

```text
README.md
docs/golden-path/README.md
docs/final-evidence-matrix.md
```

Say:

```text
I structured the repo so every platform claim has a file, runbook, ADR, or
validation command behind it.
```

### 2. Local Validation

Run:

```powershell
go test ./...
make helm-cpemon-validate
make final-portfolio-check
```

### 3. GitOps and Platform Addons

Show:

```text
k8s/gitops/dev/applications/
k8s/addons/
deploy/helm/cpemon/
```

### 4. Kafka Pipeline

Show:

```text
app/pkg/events/
app/acs-ingest/
app/cpemon-writer/
ops/runbooks/cpemon-writer-kafka-to-db-validation.md
```

### 5. Canary Safety

Show:

```text
deploy/helm/cpemon/templates/analysis-templates.yaml
ops/demos/argo-rollouts/
ops/runbooks/argo-rollouts-cpemon-api.md
```

### 6. Observability and Governance

Show:

```text
k8s/monitoring/
k8s/policies/kyverno/
k8s/addons/opencost/
```

### 7. Crossplane and K8sGPT

Show:

```text
k8s/crossplane/
k8s/k8sgpt/
docs/knowledge/crossplane-developer-self-service.md
docs/knowledge/k8sgpt-detective-layer.md
```

### 8. Incident Drill

Walk through:

```text
docs/golden-path/05-operational-runbook.md
```

## Fallback Demo Mode

If there is no live cluster, demo the repository evidence:

* render Helm;
* run Go tests;
* run validation scripts;
* show Argo CD Application manifests;
* show runbooks and controlled demo manifests;
* explain live validation prerequisites honestly.
