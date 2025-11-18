#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-cpemon}"
API_HOST="${API_HOST:-https://api.local}"

CPE_SN="${CPE_SN:-CPE-TR069-DEMO}"
COUNT="${COUNT:-30}"       # 发送多少次“心跳”
SLEEP_SEC="${SLEEP_SEC:-2}" # 每次间隔多少秒

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2
}

log "=== CPE + (simulated) ACS → CPEmon demo ==="
log "Namespace: ${NS}"
log "API host:  ${API_HOST}"
log "CPE SN:    ${CPE_SN}"
log "Count:     ${COUNT}, interval: ${SLEEP_SEC}s"
echo

############################################################
# 1. 展示当前 pipeline 状态：acs-ingest / cpemon-api / writer
############################################################
log "[Step 1] Show cpemon pods"
kubectl -n "${NS}" get deploy,pods -o wide

echo
log "Hint: 在 Grafana 打开 'CPEMon Pipeline Overview' dashboard，"
log "      看下面三个 panel："
log "      - ACS Webhook Requests (如果你有做)"
log "      - cpemon-api: HTTP Requests by Status"
log "      - cpemon-writer: Events (processed / failed / dead)"
echo

############################################################
# 2. 用 curl 模拟 “CPE 通过 ACS 上报心跳”
#    （这里用的是简化的 /cpe/heartbeat 接口）
############################################################
log "[Step 2] Sending simulated CPE heartbeats via ${API_HOST}/cpe/heartbeat"
for i in $(seq 1 "${COUNT}"); do
  cpu=$((20 + (i % 5)))
  mem=$((40 + (i % 15)))

  payload=$(cat <<EOF
{"sn":"${CPE_SN}","wan_ip":"10.0.0.2","sw_version":"v1.0","cpu_pct":${cpu},"mem_pct":${mem}}
EOF
)

  log "  -> heartbeat #${i}, cpu=${cpu}, mem=${mem}"
  curl -sk -X POST "${API_HOST}/cpe/heartbeat" \
    -H "Content-Type: application/json" \
    -d "${payload}" >/dev/null 2>&1

  sleep "${SLEEP_SEC}"
done

echo
log "Done sending heartbeats."

############################################################
# 3. 从 cpemon-api 查询这个 CPE 的最新状态
############################################################
log "[Step 3] Query cpemon-api for CPE: ${CPE_SN}"
curl -sk "${API_HOST}/api/cpe/${CPE_SN}" || true
echo

############################################################
# 4. 提示如何在 Grafana 里看这次流量
############################################################
cat <<EOF

[INFO] Demo narration hints:

  1) 在 Grafana 选 time range = "Last 15 minutes"，自动刷新 5s。
  2) 看 "cpemon-api: HTTP Requests by Status"：
       - 这次脚本会让 code=202 的那条线明显往上跳一截。
  3) 看 "cpemon-writer: Events (processed / failed / dead, 5m)"：
       - processed 会有一个对应的突刺，说明 writer 正在消费队列。
  4) 如果你有给 acs-ingest 做 metrics（比如 acs_webhook_requests_total）：
       - 可以再切到对应 Panel，说这其实就是 GenieACS Webhook 的视角。

[INFO] 真实环境下，这些 heartbeat 是通过：
        CPE → TR-069 → GenieACS → ACS Webhook (/acs/webhook) → acs-ingest
       这里只是用脚本直接打 /cpe/heartbeat 来模拟 TR-069 那一段。

=== CPE + ACS demo finished ===
EOF

