#!/usr/bin/env bash
set -euo pipefail

# make_backlog.sh
# Queue backlog demo:
#   1) scale cpemon-writer down to 0 (pause consumer)
#   2) send a burst of heartbeat events via cpemon-api (create backlog)
#   3) wait a bit so you can see backlog grow in Grafana
#   4) scale cpemon-writer back to the original replica count
#
# You can then watch the "queue depth / lag" panel in Grafana go up and down.

APP_NAMESPACE="${APP_NAMESPACE:-cpemon}"
WRITER_DEPLOYMENT="${WRITER_DEPLOYMENT:-cpemon-writer}"

# Where to send heartbeat events.
# Default is to go through Ingress: https://api.local + /api/cpe/heartbeat
API_BASE_URL="${API_BASE_URL:-https://api.local}"
HEARTBEAT_PATH="${HEARTBEAT_PATH:-/cpe/heartbeat}"

# If you prefer to hardcode a full URL (e.g. http://localhost:8080/cpe/heartbeat),
# set HEARTBEAT_URL and it will override API_BASE_URL/HEARTBEAT_PATH.
HEARTBEAT_URL="${HEARTBEAT_URL:-}"

# How many heartbeat events to send while the writer is paused.
HEARTBEAT_COUNT="${HEARTBEAT_COUNT:-200}"

# Small delay between requests to avoid spamming too hard (seconds, can be float).
HEARTBEAT_DELAY="${HEARTBEAT_DELAY:-0.05}"

# How long to keep the writer paused *after* sending heartbeats,
# so that you can look at the Grafana dashboard and see backlog increasing.
PAUSE_BEFORE_RESUME="${PAUSE_BEFORE_RESUME:-20}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

run() {
  log "+ $*"
  "$@"
}

ORIGINAL_REPLICAS=""

cleanup() {
  # Always try to restore the original replica count on exit.
  if [[ -n "${ORIGINAL_REPLICAS}" ]]; then
    log "Cleanup: scaling ${WRITER_DEPLOYMENT} back to ${ORIGINAL_REPLICAS} replicas in ${APP_NAMESPACE}"
    kubectl -n "${APP_NAMESPACE}" scale deploy "${WRITER_DEPLOYMENT}" --replicas="${ORIGINAL_REPLICAS}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

log "=== Queue backlog demo: pause writer, create backlog, resume writer ==="

# Step 0: basic dependency checks
for bin in kubectl curl; do
  if ! command -v "${bin}" >/dev/null 2>&1; then
    log "ERROR: ${bin} not found in PATH"
    exit 1
  fi
done

# Step 1: show current writer status
log "Step 1: Current ${WRITER_DEPLOYMENT} status in namespace ${APP_NAMESPACE}:"
kubectl -n "${APP_NAMESPACE}" get deploy "${WRITER_DEPLOYMENT}" || {
  log "ERROR: Deployment ${WRITER_DEPLOYMENT} not found in namespace ${APP_NAMESPACE}"
  exit 1
}

# Read current replica count
ORIGINAL_REPLICAS="$(kubectl -n "${APP_NAMESPACE}" get deploy "${WRITER_DEPLOYMENT}" -o jsonpath='{.spec.replicas}')"
if [[ -z "${ORIGINAL_REPLICAS}" ]]; then
  ORIGINAL_REPLICAS="1"
fi
log "Detected replicas: ${WRITER_DEPLOYMENT}=${ORIGINAL_REPLICAS}"

# Step 2: scale writer down to 0 to pause queue consumer
log "Step 2: Scaling ${WRITER_DEPLOYMENT} down to 0 (pause the queue consumer)..."
run kubectl -n "${APP_NAMESPACE}" scale deploy "${WRITER_DEPLOYMENT}" --replicas=0
log "Waiting a few seconds for writer pods to terminate..."
sleep 5

log "Writer pods after scale-down (should be 0 or Terminating):"
kubectl -n "${APP_NAMESPACE}" get pods -l app="${WRITER_DEPLOYMENT}" || true

# Step 3: send heartbeat events while the writer is paused
if [[ -z "${HEARTBEAT_URL}" ]]; then
  HEARTBEAT_URL="${API_BASE_URL}${HEARTBEAT_PATH}"
fi

log "Step 3: Sending ${HEARTBEAT_COUNT} heartbeat events to ${HEARTBEAT_URL}"
log "NOTE: If your endpoint is different, run with HEARTBEAT_URL=... to override."

for i in $(seq 1 "${HEARTBEAT_COUNT}"); do
  # simulate multiple CPEs
  sn="CPE-DEMO-${i}"
  payload=$(printf '{"sn":"%s","wan_ip":"10.0.0.2","sw_version":"v1.0","cpu_pct":20,"mem_pct":40}' "${sn}")

  if curl -sS -k -X POST "${HEARTBEAT_URL}" \
    -H "Content-Type: application/json" \
    -d "${payload}" >/dev/null; then
    if (( i % 20 == 0 )); then
      log "  Sent ${i}/${HEARTBEAT_COUNT} heartbeats..."
    fi
  else
    log "WARN: heartbeat request ${i} failed"
  fi

  sleep "${HEARTBEAT_DELAY}"
done

log "Finished sending heartbeat events."
log "At this point, the queue should have built up backlog while the writer was paused."
log "HINT: open Grafana dashboard 'cpemon-pipeline' and watch the queue depth / lag panels go UP."

if (( PAUSE_BEFORE_RESUME > 0 )); then
  log "Step 3.5: Waiting ${PAUSE_BEFORE_RESUME}s before resuming the writer (for Grafana observation)..."
  sleep "${PAUSE_BEFORE_RESUME}"
fi

# Step 4: resume the writer
log "Step 4: Resuming ${WRITER_DEPLOYMENT} to ${ORIGINAL_REPLICAS} replicas..."
run kubectl -n "${APP_NAMESPACE}" scale deploy "${WRITER_DEPLOYMENT}" --replicas="${ORIGINAL_REPLICAS}"

log "Waiting for writer deployment rollout..."
kubectl -n "${APP_NAMESPACE}" rollout status deploy/"${WRITER_DEPLOYMENT}" --timeout=120s || true

log "Writer resumed. Queue backlog / lag should now start to drain in Grafana."
log "HINT: on the same dashboard, watch the queue depth / lag panels go DOWN."
log "=== Queue backlog demo finished ==="
