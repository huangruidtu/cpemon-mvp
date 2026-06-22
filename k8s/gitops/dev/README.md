# Dev GitOps Environment

The `dev` environment is the first CPEmon Argo CD target.

It maps to the learning EKS cluster and uses repository paths that already
exist in the upgrade:

* CPEmon application chart: `deploy/helm/cpemon`
* CPEmon dev values: `deploy/helm/cpemon/values-dev.yaml`
* Kafka values: `k8s/addons/kafka/values.yaml`
* Kyverno values: `k8s/addons/kyverno/values.yaml`
* Kyverno policies: `k8s/policies/kyverno`
* Argo CD Application manifests: `k8s/gitops/dev/applications`

The environment is intentionally simple. Production promotion, multiple
clusters, and app-of-apps orchestration are deferred until the GitOps boundary
is proven.
