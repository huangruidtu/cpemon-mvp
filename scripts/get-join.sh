#!/usr/bin/env bash
set -euo pipefail
kubeadm token create --print-join-command
echo "👉 Remember to append: --cri-socket unix:///var/run/cri-dockerd.sock"
