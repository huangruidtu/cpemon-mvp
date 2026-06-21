KUBECONFIG ?= $(HOME)/.kube/config
AWS_REGION ?= eu-north-1
EKS_CLUSTER_NAME ?= cpemon-dev
EKS_VPC_ID ?=
AWS_LBC_ROLE_ARN ?=
METRICS_SERVER_CHART_VERSION ?= 3.13.1
AWS_LBC_CHART_VERSION ?= 1.14.0
HELM ?= helm
HELM_CPEMON_CHART ?= deploy/helm/cpemon
HELM_CPEMON_RELEASE ?= cpemon
HELM_CPEMON_NAMESPACE ?= cpemon
HELM_CPEMON_VALUES ?= deploy/helm/cpemon/values-dev.yaml
HELM_CPEMON_RENDER_OUT ?= build/helm/cpemon-rendered.yaml

.PHONY: platform-preflight platform-manifest-plan platform-checks ns ns-check helm-repos metrics-server metrics-server-check aws-lbc aws-lbc-check storage-check storage-gp3-plan storage-gp3-apply echo echo-check echo-port-forward echo-ingress echo-ingress-check netpol-check netpol-baseline-plan calico ingress pdb smoke helm-check helm-cpemon-lint helm-cpemon-template helm-cpemon-validate cpemon-api-db-check

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
