#!/usr/bin/env bash
set -euo pipefail
kubectl get nodes -o wide
kubectl -n ingress-nginx get pods -o wide || true
curl -sI -k https://api.local || true
