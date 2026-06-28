KUBECONFIG ?= $(HOME)/.kube/config
AWS_REGION ?= eu-north-1
EKS_CLUSTER_NAME ?= cpemon-dev
EKS_VPC_ID ?=
AWS_LBC_ROLE_ARN ?=
METRICS_SERVER_CHART_VERSION ?= 3.13.1
AWS_LBC_CHART_VERSION ?= 1.14.0
KAFKA_CHART ?= oci://registry-1.docker.io/bitnamicharts/kafka
KAFKA_CHART_VERSION ?= 32.4.3
KAFKA_RELEASE ?= kafka
KAFKA_NAMESPACE ?= kafka
KAFKA_VALUES ?= k8s/addons/kafka/values.yaml
KAFKA_RENDER_OUT ?= build/helm/kafka-rendered.yaml
KPS_CHART ?= oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack
KPS_CHART_VERSION ?= 86.3.2
KPS_RELEASE ?= kps
KPS_NAMESPACE ?= monitoring
KPS_VALUES ?= k8s/monitoring/kube-prometheus-stack-values.yaml
ESO_CHART_REPO ?= external-secrets
ESO_CHART ?= external-secrets/external-secrets
ESO_CHART_VERSION ?= 2.6.0
ESO_RELEASE ?= external-secrets
ESO_NAMESPACE ?= external-secrets
ESO_VALUES ?= k8s/addons/external-secrets/values.yaml
HELM ?= helm
HELM_CPEMON_CHART ?= deploy/helm/cpemon
HELM_CPEMON_RELEASE ?= cpemon
HELM_CPEMON_NAMESPACE ?= cpemon
HELM_CPEMON_VALUES ?= deploy/helm/cpemon/values-dev.yaml
HELM_CPEMON_RENDER_OUT ?= build/helm/cpemon-rendered.yaml
K8SGPT_CHART_REPO ?= k8sgpt
K8SGPT_CHART ?= k8sgpt/k8sgpt-operator
K8SGPT_CHART_VERSION ?= 0.2.27
K8SGPT_RELEASE ?= k8sgpt
K8SGPT_NAMESPACE ?= k8sgpt-operator-system
K8SGPT_VALUES ?= k8s/addons/k8sgpt/values.yaml

.PHONY: platform-preflight platform-manifest-plan platform-checks ns ns-check helm-repos metrics-server metrics-server-check aws-lbc aws-lbc-check kafka-namespace-check kafka-topics-check kafka-topic-naming-check kafka-config-check kafka-architecture-docs-check kafka-produce-consume-runbook-check kafka-validation-observability-check kafka-learning-notes-check kafka-metrics-boundary-check acs-ingest-heartbeat-schema-check acs-ingest-wan-status-schema-check acs-ingest-event-publisher-check acs-ingest-kafka-config-check acs-ingest-kafka-producer-check acs-ingest-publish-wiring-check acs-ingest-producer-retry-check acs-ingest-producer-observability-check acs-ingest-ingestion-metrics-check acs-ingest-unit-tests-check acs-ingest-kafka-producer-validation-check acs-ingest-kafka-producer-docs-check acs-ingest-kafka-producer-learning-notes-check cpemon-writer-kafka-consumer-config-check cpemon-writer-kafka-consumer-group-check cpemon-writer-heartbeat-subscription-check cpemon-writer-wan-status-subscription-check cpemon-writer-heartbeat-write-model-check cpemon-writer-wan-status-write-model-check cpemon-writer-event-processor-check cpemon-writer-offset-commit-check cpemon-writer-retry-deadletter-check cpemon-writer-consumer-lag-check cpemon-writer-processing-observability-check cpemon-writer-observability-story12-check cpemon-writer-consumer-unit-tests-check cpemon-writer-kafka-to-db-validation-check cpemon-api-kafka-status-validation-check cpemon-writer-kafka-consumer-operations-check cpemon-writer-kafka-consumer-learning-notes-check crossplane-terraform-boundary-check argocd-crossplane-installation-check crossplane-aws-provider-irsa-check crossplane-platform-api-conventions-check crossplane-s3-bucket-platform-api-check crossplane-dynamodb-table-platform-api-check crossplane-ecr-repository-platform-api-check crossplane-developer-requests-check argocd-crossplane-wiring-check crossplane-policy-guardrails-check crossplane-connection-outputs-check crossplane-story-check crossplane-offline-validation-docs-check k8sgpt-detective-layer-check argocd-installation-check argocd-project-check argocd-gitops-layout-check argocd-cpemon-application-check argocd-kafka-application-check argocd-monitoring-application-check argocd-external-secrets-application-check argocd-kyverno-installation-check argocd-opencost-installation-check opencost-prometheus-integration-check opencost-namespace-cost-visibility-check opencost-cost-investigation-check cpemon-api-hpa-check cpemon-api-hpa-validation-check keda-step2-decision-check platform-governance-cost-autoscaling-docs-check platform-governance-cost-autoscaling-final-check kyverno-resource-policy-check kyverno-image-tag-policy-check kyverno-labels-nonroot-policies-check kyverno-policy-fixtures-check argocd-policy-security-application-check argocd-sync-policy-check argocd-prune-self-heal-check argocd-gitops-deployment-validation-check argocd-drift-detection-check argocd-ci-cd-separation-check argocd-runbook-adr-interview-check argo-rollouts-controller-check argo-rollouts-local-tooling-check cpemon-api-rollout-check cpemon-api-rollout-services-check cpemon-api-canary-steps-check cpemon-api-prometheus-analysis-inputs-check cpemon-api-http5xx-analysis-check cpemon-api-p95-analysis-check cpemon-api-analysis-wiring-check cpemon-api-rollout-status-check cpemon-api-promote-abort-check cpemon-api-healthy-canary-demo-check cpemon-api-failed-canary-demo-check cpemon-api-successful-rollout-demo-script-check cpemon-api-failed-rollout-demo-script-check argo-rollouts-final-docs-check monitoring-gitops-check cpemon-servicemonitor-check monitoring-template external-secrets-template kafka-chart-show kafka-template kafka kafka-check kafka-validate k8sgpt-template storage-check storage-gp3-plan storage-gp3-apply echo echo-check echo-port-forward echo-ingress echo-ingress-check netpol-check netpol-baseline-plan calico ingress pdb smoke helm-check helm-cpemon-lint helm-cpemon-template helm-cpemon-validate cpemon-api-db-check cpemon-writer-db-check cpemon-eso-render-check kafka-helm-workflow-check

platform-preflight:
	kubectl version --client=true
	helm version
	aws --version
	kubectl config current-context
	kubectl cluster-info

platform-manifest-plan:
	kubectl apply --dry-run=client -f k8s/base/namespaces.yaml
	kubectl apply --dry-run=client -f k8s/addons/storage/gp3-storageclass.yaml
	kubectl apply --dry-run=client -f k8s/samples/echo/deploy.yaml
	kubectl apply --dry-run=client -f k8s/samples/echo/svc.yaml
	kubectl apply --dry-run=client -f k8s/samples/echo/ing.yaml
	kubectl apply --dry-run=client -f k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml

platform-checks: platform-preflight ns-check metrics-server-check aws-lbc-check storage-check echo-check echo-ingress-check netpol-check

ns:
	kubectl apply -f k8s/base/namespaces.yaml

ns-check:
	kubectl get ns cpemon platform monitoring argocd kafka security cost backup ingress-nginx
	kubectl get ns -L cpemon.io/layer,cpemon.io/managed-by

kafka-namespace-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-namespace.ps1

kafka-topics-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-topics.ps1

kafka-topic-naming-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-topic-naming.ps1

kafka-config-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-config-boundary.ps1

kafka-architecture-docs-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-architecture-docs.ps1

kafka-produce-consume-runbook-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-produce-consume-runbook.ps1

kafka-validation-observability-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-validation-observability.ps1

kafka-learning-notes-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-learning-notes.ps1

kafka-metrics-boundary-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-metrics-boundary.ps1

acs-ingest-heartbeat-schema-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-heartbeat-schema.ps1

acs-ingest-wan-status-schema-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-wan-status-schema.ps1

acs-ingest-event-publisher-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-event-publisher.ps1

acs-ingest-kafka-config-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-kafka-config.ps1

acs-ingest-kafka-producer-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-kafka-producer.ps1

acs-ingest-publish-wiring-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-publish-wiring.ps1

acs-ingest-producer-retry-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-producer-retry.ps1

acs-ingest-producer-observability-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-producer-observability.ps1

acs-ingest-ingestion-metrics-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-ingestion-metrics.ps1

acs-ingest-unit-tests-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-unit-tests.ps1

acs-ingest-kafka-producer-validation-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-kafka-producer-validation.ps1

acs-ingest-kafka-producer-docs-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-kafka-producer-docs.ps1

acs-ingest-kafka-producer-learning-notes-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-acs-ingest-kafka-producer-learning-notes.ps1

cpemon-writer-kafka-consumer-config-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-kafka-consumer-config.ps1

cpemon-writer-kafka-consumer-group-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-kafka-consumer-group.ps1

cpemon-writer-heartbeat-subscription-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-heartbeat-subscription.ps1

cpemon-writer-wan-status-subscription-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-wan-status-subscription.ps1

cpemon-writer-heartbeat-write-model-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-heartbeat-write-model.ps1

cpemon-writer-wan-status-write-model-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-wan-status-write-model.ps1

cpemon-writer-event-processor-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-event-processor.ps1

cpemon-writer-offset-commit-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-offset-commit.ps1

cpemon-writer-retry-deadletter-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-retry-deadletter.ps1

cpemon-writer-consumer-lag-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-consumer-lag.ps1

cpemon-writer-processing-observability-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-processing-observability.ps1

cpemon-writer-observability-story12-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-writer-consumer-observability-story12.ps1

cpemon-writer-consumer-unit-tests-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-consumer-unit-tests.ps1

cpemon-writer-kafka-to-db-validation-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-kafka-to-db-validation.ps1

cpemon-api-http-metrics-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-http-metrics.ps1

grafana-pipeline-dashboard-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-grafana-pipeline-dashboard.ps1

grafana-api-health-dashboard-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-grafana-api-health-dashboard.ps1

prometheus-alert-baseline-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-prometheus-alert-baseline.ps1

otel-collector-boundary-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-otel-collector-boundary.ps1

minimal-tracing-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-minimal-tracing.ps1

trace-id-structured-logs-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-trace-id-structured-logs.ps1

trace-export-boundary-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-trace-export-boundary.ps1

observability-e2e-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-observability-end-to-end.ps1

monitoring-observability-final-docs-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-monitoring-observability-final-docs.ps1

cpemon-api-kafka-status-validation-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-kafka-status-validation.ps1

cpemon-writer-kafka-consumer-operations-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-kafka-consumer-operations.ps1

cpemon-writer-kafka-consumer-learning-notes-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-kafka-consumer-learning-notes.ps1

crossplane-terraform-boundary-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-terraform-boundary.ps1

argocd-crossplane-installation-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-crossplane-installation.ps1

crossplane-aws-provider-irsa-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-aws-provider-irsa.ps1

crossplane-platform-api-conventions-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-platform-api-conventions.ps1

crossplane-s3-bucket-platform-api-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-s3-bucket-platform-api.ps1

crossplane-dynamodb-table-platform-api-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-dynamodb-table-platform-api.ps1

crossplane-ecr-repository-platform-api-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-ecr-repository-platform-api.ps1

crossplane-developer-requests-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-developer-requests.ps1

argocd-crossplane-wiring-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-crossplane-wiring.ps1

crossplane-policy-guardrails-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-policy-guardrails.ps1

crossplane-connection-outputs-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-connection-outputs.ps1

crossplane-story-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-story.ps1

crossplane-offline-validation-docs-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-offline-validation-docs.ps1

crossplane-lifecycle-runbook-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-lifecycle-runbook.ps1

crossplane-adr-knowledge-interview-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-adr-knowledge-interview.ps1

crossplane-final-checklist-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-crossplane-final-checklist.ps1

k8sgpt-detective-layer-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-k8sgpt-detective-layer.ps1

argocd-installation-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-installation.ps1

argocd-project-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-project.ps1

argocd-gitops-layout-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-gitops-layout.ps1

argocd-cpemon-application-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-cpemon-application.ps1

argocd-kafka-application-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-kafka-application.ps1

argocd-monitoring-application-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-monitoring-application.ps1

argocd-external-secrets-application-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-external-secrets-application.ps1

argocd-kyverno-installation-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-kyverno-installation.ps1

argocd-opencost-installation-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-opencost-installation.ps1

opencost-prometheus-integration-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-prometheus-integration.ps1

opencost-namespace-cost-visibility-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-namespace-cost-visibility.ps1

opencost-cost-investigation-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-opencost-cost-investigation.ps1

cpemon-api-hpa-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-hpa.ps1

cpemon-api-hpa-validation-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-hpa-validation.ps1

keda-step2-decision-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-keda-step2-decision.ps1

platform-governance-cost-autoscaling-docs-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-platform-governance-cost-autoscaling-docs.ps1

platform-governance-cost-autoscaling-final-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-platform-governance-cost-autoscaling-final.ps1

kyverno-resource-policy-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-resource-policy.ps1

kyverno-image-tag-policy-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-image-tag-policy.ps1

kyverno-labels-nonroot-policies-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-labels-nonroot-policies.ps1

kyverno-policy-fixtures-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kyverno-policy-fixtures.ps1

argocd-policy-security-application-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-policy-security-application.ps1

argocd-sync-policy-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-sync-policy.ps1

argocd-prune-self-heal-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-prune-self-heal-guardrails.ps1

argocd-gitops-deployment-validation-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-gitops-deployment-validation.ps1

argocd-drift-detection-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-drift-detection-validation.ps1

argocd-ci-cd-separation-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-ci-cd-separation.ps1

argocd-runbook-adr-interview-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argocd-runbook-adr-interview.ps1

argo-rollouts-controller-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argo-rollouts-controller.ps1

argo-rollouts-local-tooling-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argo-rollouts-local-tooling.ps1

cpemon-api-rollout-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-rollout.ps1

cpemon-api-rollout-services-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-rollout-services.ps1

cpemon-api-canary-steps-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-canary-steps.ps1

cpemon-api-prometheus-analysis-inputs-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-prometheus-analysis-inputs.ps1

platform-governance-boundary-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-platform-governance-boundary.ps1

cpemon-api-http5xx-analysis-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-http5xx-analysis.ps1

cpemon-api-p95-analysis-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-p95-analysis.ps1

cpemon-api-analysis-wiring-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-analysis-wiring.ps1

cpemon-api-rollout-status-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-rollout-status-runbook.ps1

cpemon-api-promote-abort-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-promote-abort-runbook.ps1

cpemon-api-healthy-canary-demo-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-healthy-canary-demo.ps1

cpemon-api-failed-canary-demo-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-failed-canary-demo.ps1

cpemon-api-successful-rollout-demo-script-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-successful-rollout-demo-script.ps1

cpemon-api-failed-rollout-demo-script-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-failed-rollout-demo-script.ps1

argo-rollouts-final-docs-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-argo-rollouts-final-docs.ps1

monitoring-gitops-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-monitoring-gitops-stack.ps1

cpemon-servicemonitor-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-servicemonitor-helm.ps1

helm-repos:
	helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
	helm repo add eks https://aws.github.io/eks-charts
	helm repo update

helm-check:
	@"$(HELM)" version --short || (echo "ERROR: Helm is required for this target. Install Helm and make sure 'helm' is on PATH, or pass HELM=/absolute/path/to/helm." && exit 1)

helm-cpemon-lint: helm-check
	"$(HELM)" lint $(HELM_CPEMON_CHART) -f $(HELM_CPEMON_VALUES)

helm-cpemon-template: helm-check
	powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path 'build/helm' | Out-Null"
	"$(HELM)" template $(HELM_CPEMON_RELEASE) $(HELM_CPEMON_CHART) -n $(HELM_CPEMON_NAMESPACE) -f $(HELM_CPEMON_VALUES) > $(HELM_CPEMON_RENDER_OUT)
	@echo "Rendered CPEmon Helm chart to $(HELM_CPEMON_RENDER_OUT)"

helm-cpemon-validate: helm-cpemon-lint helm-cpemon-template

metrics-server:
	helm upgrade --install metrics-server metrics-server/metrics-server \
	  --namespace kube-system \
	  --version $(METRICS_SERVER_CHART_VERSION) \
	  --values k8s/addons/metrics-server/values.yaml

metrics-server-check:
	kubectl get deployment -n kube-system metrics-server
	kubectl top nodes
	kubectl top pods -A

aws-lbc:
	test -n "$(EKS_VPC_ID)"
	test -n "$(AWS_LBC_ROLE_ARN)"
	helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
	  --namespace kube-system \
	  --version $(AWS_LBC_CHART_VERSION) \
	  --values k8s/addons/aws-load-balancer-controller/values.yaml \
	  --set clusterName=$(EKS_CLUSTER_NAME) \
	  --set region=$(AWS_REGION) \
	  --set vpcId=$(EKS_VPC_ID) \
	  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(AWS_LBC_ROLE_ARN)

aws-lbc-check:
	kubectl get deployment -n kube-system aws-load-balancer-controller
	kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=80

kafka-chart-show: helm-check
	"$(HELM)" show chart $(KAFKA_CHART) --version $(KAFKA_CHART_VERSION)

kafka-template: helm-check
	powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path 'build/helm' | Out-Null"
	"$(HELM)" template $(KAFKA_RELEASE) $(KAFKA_CHART) \
	  --namespace $(KAFKA_NAMESPACE) \
	  --version $(KAFKA_CHART_VERSION) \
	  --values $(KAFKA_VALUES) > $(KAFKA_RENDER_OUT)
	@echo "Rendered Kafka Helm chart to $(KAFKA_RENDER_OUT)"

kafka: helm-check
	"$(HELM)" upgrade --install $(KAFKA_RELEASE) $(KAFKA_CHART) \
	  --namespace $(KAFKA_NAMESPACE) \
	  --version $(KAFKA_CHART_VERSION) \
	  --values $(KAFKA_VALUES) \
	  --wait \
	  --timeout 10m

kafka-check:
	"$(HELM)" status $(KAFKA_RELEASE) -n $(KAFKA_NAMESPACE)
	kubectl get pods,svc,statefulset,pvc -n $(KAFKA_NAMESPACE)
	kubectl rollout status statefulset/$(KAFKA_RELEASE)-controller -n $(KAFKA_NAMESPACE) --timeout=10m

kafka-validate: kafka-template

monitoring-template: helm-check
	"$(HELM)" template $(KPS_RELEASE) $(KPS_CHART) \
	  --namespace $(KPS_NAMESPACE) \
	  --version $(KPS_CHART_VERSION) \
	  --values $(KPS_VALUES)

external-secrets-template: helm-check
	"$(HELM)" repo add $(ESO_CHART_REPO) https://charts.external-secrets.io
	"$(HELM)" repo update $(ESO_CHART_REPO)
	"$(HELM)" template $(ESO_RELEASE) $(ESO_CHART) \
	  --namespace $(ESO_NAMESPACE) \
	  --version $(ESO_CHART_VERSION) \
	  --values $(ESO_VALUES)

k8sgpt-template: helm-check
	"$(HELM)" repo add $(K8SGPT_CHART_REPO) https://charts.k8sgpt.ai/
	"$(HELM)" repo update $(K8SGPT_CHART_REPO)
	"$(HELM)" template $(K8SGPT_RELEASE) $(K8SGPT_CHART) \
	  --namespace $(K8SGPT_NAMESPACE) \
	  --version $(K8SGPT_CHART_VERSION) \
	  --values $(K8SGPT_VALUES)

storage-check:
	kubectl get storageclass
	kubectl get storageclass -o custom-columns=NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\\.kubernetes\\.io/is-default-class,PROVISIONER:.provisioner,VOLUME_BINDING:.volumeBindingMode,ALLOW_EXPANSION:.allowVolumeExpansion

storage-gp3-plan:
	kubectl apply --dry-run=client -f k8s/addons/storage/gp3-storageclass.yaml

storage-gp3-apply:
	kubectl apply -f k8s/addons/storage/gp3-storageclass.yaml

echo:
	kubectl apply -f k8s/samples/echo/deploy.yaml
	kubectl apply -f k8s/samples/echo/svc.yaml

echo-check:
	kubectl get deploy,svc,pods -n platform -l app.kubernetes.io/name=echo
	kubectl rollout status deployment/echo -n platform
	kubectl describe pod -n platform -l app.kubernetes.io/name=echo

echo-port-forward:
	kubectl port-forward -n platform svc/echo 8080:80

echo-ingress:
	kubectl apply -f k8s/samples/echo/ing.yaml

echo-ingress-check:
	kubectl get ingress echo -n platform
	kubectl describe ingress echo -n platform
	kubectl get ingress echo -n platform -o jsonpath="{.status.loadBalancer.ingress[0].hostname}{'\n'}"

netpol-check:
	kubectl get networkpolicy -A
	kubectl describe networkpolicy -n cpemon

netpol-baseline-plan:
	kubectl apply --dry-run=client -f k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml

calico:
	kubectl apply -f k8s/calico/calico.yaml
	kubectl -n kube-system rollout status ds/calico-node

ingress:
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo update
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
	  -n ingress-nginx -f k8s/ingress-nginx/values.yaml
	kubectl -n ingress-nginx get pods -o wide

pdb:
	kubectl apply -f k8s/pdb/

smoke:
	kubectl get nodes -o wide
	kubectl -n ingress-nginx get pods -o wide || true
	@echo "Try: curl -I -k https://api.local  (expect 404)"

cpemon-api-db-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-api-db.ps1

cpemon-writer-db-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-writer-db.ps1

cpemon-eso-render-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-cpemon-eso-render.ps1

kafka-helm-workflow-check:
	powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-helm-workflow.ps1
