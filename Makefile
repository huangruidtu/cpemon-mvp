KUBECONFIG ?= $(HOME)/.kube/config

.PHONY: ns calico ingress pdb smoke

ns:
	kubectl apply -f k8s/base/namespaces.yaml

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
