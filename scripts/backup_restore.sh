#!/usr/bin/env bash
set -euo pipefail

# One-click demo for Velero backup + delete + restore of the cpemon namespace.
#
# Flow:
#   1) velero backup create ... (cpemon ns)
#   2) delete cpemon-api Deployment/Service/Ingress
#   3) velero restore create ... --from-backup ...
#   4) verify cpemon-api is back
#   5) run scripts/smoke.sh (if present)

APP_NAMESPACE="${APP_NAMESPACE:-cpemon}"
VELERO_NAMESPACE="${VELERO_NAMESPACE:-backup}"
API_DEPLOYMENT="${API_DEPLOYMENT:-cpemon-api}"
API_SERVICE="${API_SERVICE:-cpemon-api}"
API_INGRESS="${API_INGRESS:-cpemon-api}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

run() {
  log "+ $*"
  # shellcheck disable=SC2068
  $@
}

# ---------- 0. 生成备份名 / 恢复名 ----------
BACKUP_NAME="${BACKUP_NAME:-cpemon-demo-$(date +%Y%m%d-%H%M%S)}"
RESTORE_NAME="${RESTORE_NAME:-${BACKUP_NAME}-restore}"

log "=== Velero backup & restore demo for namespace: ${APP_NAMESPACE} ==="
log "Backup will be created as: ${BACKUP_NAME}"
log "Restore will be created as: ${RESTORE_NAME}"
echo

# ---------- 1. 创建备份 ----------
log "Step 1: Creating Velero backup..."
run velero backup create "${BACKUP_NAME}" \
  --include-namespaces "${APP_NAMESPACE}" \
  --namespace "${VELERO_NAMESPACE}"

log "Waiting for backup to reach phase=Completed..."
STATUS="Unknown"
for i in {1..30}; do
  STATUS=$(kubectl -n "${VELERO_NAMESPACE}" get backups.velero.io "${BACKUP_NAME}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
  log "  Backup status: ${STATUS}"
  if [[ "${STATUS}" == "Completed" ]]; then
    break
  fi
  if [[ "${STATUS}" == "Failed" ]]; then
    log "ERROR: backup ${BACKUP_NAME} failed."
    exit 1
  fi
  sleep 5
done

if [[ "${STATUS}" != "Completed" ]]; then
  log "ERROR: backup ${BACKUP_NAME} did not reach Completed state in time."
  exit 1
fi

log "Backup ${BACKUP_NAME} is Completed."
echo

# ---------- 2. 模拟故障：删除 cpemon-api ----------
log "Step 2: Simulating failure by deleting ${API_DEPLOYMENT}/${API_SERVICE}/${API_INGRESS} in ${APP_NAMESPACE}"
log "WARNING: This is destructive for the demo namespace. Ctrl+C now if you don't want to proceed."
sleep 5

log "Current cpemon-api resources before deletion:"
run kubectl -n "${APP_NAMESPACE}" get deploy,svc,ingress | grep "${API_DEPLOYMENT}" || true

run kubectl -n "${APP_NAMESPACE}" delete deploy "${API_DEPLOYMENT}" --ignore-not-found=true
run kubectl -n "${APP_NAMESPACE}" delete svc "${API_SERVICE}" --ignore-not-found=true
run kubectl -n "${APP_NAMESPACE}" delete ingress "${API_INGRESS}" --ignore-not-found=true

log "After deletion:"
run kubectl -n "${APP_NAMESPACE}" get deploy,svc,ingress || true
run kubectl -n "${APP_NAMESPACE}" get pods || true
echo

# ---------- 3. 从备份恢复 ----------
log "Step 3: Restoring from backup ${BACKUP_NAME}..."
run velero restore create "${RESTORE_NAME}" \
  --from-backup "${BACKUP_NAME}" \
  --namespace "${VELERO_NAMESPACE}"

log "Waiting for restore to reach phase=Completed..."
STATUS="Unknown"
for i in {1..30}; do
  STATUS=$(kubectl -n "${VELERO_NAMESPACE}" get restores.velero.io "${RESTORE_NAME}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
  log "  Restore status: ${STATUS}"
  if [[ "${STATUS}" == "Completed" ]]; then
    break
  fi
  if [[ "${STATUS}" == "Failed" ]]; then
    log "ERROR: restore ${RESTORE_NAME} failed."
    exit 1
  fi
  sleep 5
done

if [[ "${STATUS}" != "Completed" ]]; then
  log "ERROR: restore ${RESTORE_NAME} did not reach Completed state in time."
  exit 1
fi

log "Restore ${RESTORE_NAME} is Completed."
echo

# ---------- 4. 验证 cpemon-api ----------
log "Step 4: Verifying cpemon-api deployment & pods..."
run kubectl -n "${APP_NAMESPACE}" get deploy,svc,ingress | grep "${API_DEPLOYMENT}" || true
run kubectl -n "${APP_NAMESPACE}" get pods -l app="${API_DEPLOYMENT}" || true
echo

# ---------- 5. 可选：跑一遍 smoke.sh ----------
if [[ -x "${SCRIPT_DIR}/smoke.sh" ]]; then
  log "Step 5: Running smoke.sh for final verification..."
  # 默认 let smoke.sh 用 https://api.local；如有需要可以在运行时覆盖 BASE_URL/NAMESPACE
  BASE_URL="${BASE_URL:-https://api.local}" \
  NAMESPACE="${APP_NAMESPACE}" \
  "${SCRIPT_DIR}/smoke.sh" || {
    log "WARNING: smoke.sh returned non-zero exit code."
  }
else
  log "smoke.sh not found or not executable under ${SCRIPT_DIR}, skipping smoke test."
fi

log "=== Backup & restore demo finished ==="

