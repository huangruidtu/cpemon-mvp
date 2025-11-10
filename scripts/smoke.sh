#!/usr/bin/env bash
set -euo pipefail

ns_required=(cpemon platform backup ingress-nginx metallb-system)

echo "== Cluster & Versions =="
kubectl get nodes -o wide

echo -e "\n-- kubectl client version --"
# 兼容新旧 kubectl：优先 YAML，其次纯文本
(kubectl version --client --output=yaml 2>/dev/null) \
  || (kubectl version --client 2>/dev/null) \
  || kubectl version 2>/dev/null || true

echo -e "\n== Namespaces Check =="
kubectl get ns "${ns_required[@]}" || true

echo -e "\n== Ingress Controller (should be Deployment) =="
kubectl -n ingress-nginx get deploy,ds,pods -o wide

echo -e "\n== MetalLB =="
kubectl -n metallb-system get ds,deploy,pods
kubectl -n metallb-system get ipaddresspools,l2advertisements

echo -e "\n== Ingress Service & LB IP =="
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
LB_IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "LB_IP=${LB_IP:-<none>}"
if [[ -z "${LB_IP}" ]]; then
  echo "FAIL: EXTERNAL-IP is empty. Check MetalLB pool/advertisement." >&2
  exit 1
fi

echo -e "\n== Node Labels/Taints (worker-only scheduling sanity) =="
kubectl get nodes --show-labels | grep ingress-worker || echo "WARN: no node with label ingress-worker=true"
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

echo -e "\n== PDBs =="
kubectl -n cpemon get pdb || true

echo -e "\n== DNS/Hosts Resolution (this host) =="
getent hosts api.local || { echo "FAIL: api.local not resolvable on this host"; exit 1; }

echo -e "\n== Smoke: Default backend should be 404 =="
curl -sS -I http://api.local | head -n 1
curl -sS -I -k https://api.local | head -n 1

echo -e "\n== Smoke: /echo should be 200 =="
curl -sS -I -k https://api.local/echo | head -n 1
# 可选查看一点正文
# curl -s -k https://api.local/echo | head -n 3

echo -e "\n== Controller recent logs (tail) =="
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller | tail -n 50 || true

echo -e "\nPASS: Smoke finished."
