#!/usr/bin/env bash
set -euo pipefail

# vm3 根目录
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ACS_COMPOSE="${BASE_DIR}/acs/docker-compose.yml"
CPE_DIR="${BASE_DIR}/cpe-sim"

# 选 docker compose / docker-compose
if docker compose version &>/dev/null; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  echo "ERROR: docker compose / docker-compose not found" >&2
  exit 1
fi

# 从 /etc/hosts 里自动找 api.local 的 IP，没有就给个默认
API_HOST="api.local"
API_IP="${API_IP:-$(grep -m1 -E "\\s${API_HOST}(\\s|\$)" /etc/hosts | awk '{print $1}' || true)}"
if [[ -z "${API_IP}" ]]; then
  API_IP="10.0.0.200"
  echo "WARN: api.local not found in /etc/hosts, defaulting to ${API_IP}" >&2
fi

NUM_CPE="${NUM_CPE:-1}"

echo "[1/3] Starting GenieACS (ACS) with ${DC} -f ${ACS_COMPOSE} up -d"
${DC} -f "${ACS_COMPOSE}" up -d

echo "[2/3] Building CPE simulator image from ${CPE_DIR}"
docker build -t cpemon-cpe-sim:latest "${CPE_DIR}"

echo "[3/3] Starting ${NUM_CPE} CPE simulator container(s) (api.local -> ${API_IP})"
for i in $(seq 1 "${NUM_CPE}"); do
  NAME="cpe-sim-${i}"
  docker rm -f "${NAME}" >/dev/null 2>&1 || true
  docker run -d --name "${NAME}" --restart=always \
    --add-host "${API_HOST}:${API_IP}" \
    cpemon-cpe-sim:latest
done

echo
echo "=== Running ACS & CPE containers on vm3 ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' | egrep 'cpe-sim-|genieacs|mongo|redis' || true

