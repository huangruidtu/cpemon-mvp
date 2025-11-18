#!/usr/bin/env bash
set -euo pipefail

# ACS webhook 地址：
# - 默认是本机 port-forward 出来的 18080
# - 如果你想直接打 ingress，也可以：
#   ACS_WEBHOOK_URL="https://api.local/acs/webhook" ./acs-webhook-demo.sh
ACS_WEBHOOK_URL="${ACS_WEBHOOK_URL:-http://127.0.0.1:18080/acs/webhook}"

# 每种场景打几次（默认 5 次，你可以 COUNT=20 ./acs-webhook-demo.sh）
COUNT="${COUNT:-5}"

echo "===> Using ACS webhook URL: ${ACS_WEBHOOK_URL}"
echo "===> Each scenario will send ${COUNT} requests"
echo

send_ok() {
  local i
  echo "---- [OK] valid webhook (should be 202) ----"
  for i in $(seq 1 "${COUNT}"); do
    local ts
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    status=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "${ACS_WEBHOOK_URL}" \
      -H 'Content-Type: application/json' \
      -d '{"sn":"CPE-DEMO-OK","event_ts":"'"${ts}"'"}')
    echo "  #${i}: HTTP ${status}"
    sleep 0.5
  done
  echo
}

send_invalid_json() {
  local i
  echo "---- [ERR] invalid_json (坏 JSON，期望 400) ----"
  for i in $(seq 1 "${COUNT}"); do
    status=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "${ACS_WEBHOOK_URL}" \
      -H 'Content-Type: application/json' \
      --data 'this-is-not-json')
    echo "  #${i}: HTTP ${status}"
    sleep 0.5
  done
  echo
}

send_missing_sn() {
  local i
  echo "---- [ERR] missing_sn (缺少 sn 字段，期望 400) ----"
  for i in $(seq 1 "${COUNT}"); do
    local ts
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    status=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "${ACS_WEBHOOK_URL}" \
      -H 'Content-Type: application/json' \
      -d '{"event_ts":"'"${ts}"'"}')
    echo "  #${i}: HTTP ${status}"
    sleep 0.5
  done
  echo
}

send_invalid_signature() {
  local i
  echo "---- [ERR] invalid_signature (错误签名，期望 401) ----"
  for i in $(seq 1 "${COUNT}"); do
    local ts
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    status=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "${ACS_WEBHOOK_URL}" \
      -H 'Content-Type: application/json' \
      -H 'X-Signature: deadbeef' \
      -d '{"sn":"CPE-DEMO-BAD-SIG","event_ts":"'"${ts}"'"}')
    echo "  #${i}: HTTP ${status}"
    sleep 0.5
  done
  echo
}

send_ok
send_invalid_json
send_missing_sn
send_invalid_signature

echo "All done. Now check Prometheus / Grafana:"
echo "  - acs_webhook_requests_total{code=\"202\"}"
echo "  - acs_webhook_errors_total{reason=\"invalid_json\"|\"missing_sn\"|\"invalid_signature\"}"

