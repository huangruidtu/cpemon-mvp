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
HELM ?= helm
HELM_CPEMON_CHART ?= deploy/helm/cpemon
HELM_CPEMON_RELEASE ?= cpemon
HELM_CPEMON_NAMESPACE ?= cpemon
HELM_CPEMON_VALUES ?= deploy/helm/cpemon/values-dev.yaml
HELM_CPEMON_RENDER_OUT ?= build/helm/cpemon-rendered.yaml

.PHONY: platform-preflight platform-manifest-plan platform-checks ns ns-check helm-repos metrics-server metrics-server-check aws-lbc aws-lbc-check kafka-namespace-check kafka-topics-check kafka-topic-naming-check kafka-config-check kafka-architecture-docs-check kafka-produce-consume-runbook-check kafka-validation-observability-check kafka-learning-notes-check acs-ingest-heartbeat-schema-check acs-ingest-wan-status-schema-check acs-ingest-event-publisher-check acs-ingest-kafka-config-check acs-ingest-kafka-producer-check acs-ingest-publish-wiring-check acs-ingest-producer-retry-check kafka-chart-show kafka-template kafka kafka-check kafka-validate storage-check storage-gp3-plan storage-gp3-apply echo echo-check echo-port-forward echo-ingress echo-ingress-check netpol-check netpol-baseline-plan calico ingress pdb smoke helm-check helm-cpemon-lint helm-cpemon-template helm-cpemon-validate cpemon-api-db-check cpemon-writer-db-check cpemon-eso-render-check kafka-helm-workflow-check

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
