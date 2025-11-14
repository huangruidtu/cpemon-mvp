#!/usr/bin/env python3
import os
import time
import json
import random
import hmac
import hashlib
import socket

import requests
import urllib3

# ======== 基本配置（支持环境变量覆盖） ========

API_URL = os.getenv("CPE_API_URL", "https://api.local/cpe/heartbeat")
SHARED_SECRET = os.getenv("CPE_HEARTBEAT_SECRET", "cpemon-demo-secret")
SN = os.getenv("CPE_SN", "CPE-DEMO-001")
WAN_IP = os.getenv("CPE_WAN_IP", "10.0.0.13")
SW_VERSION = os.getenv("CPE_SW_VERSION", "v1.0-demo")
INTERVAL = int(os.getenv("CPE_HEARTBEAT_INTERVAL", "15"))  # seconds

# 是否校验证书：实验环境通常是自签名证书，这里默认关掉
VERIFY_SSL = os.getenv("CPE_VERIFY_SSL", "false").lower() == "true"
if not VERIFY_SSL:
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def get_hostname():
    try:
        return socket.gethostname()
    except Exception:
        return "unknown-host"


def build_payload():
    """
    构造一条心跳数据：
    - CPU/MEM 用随机数模拟
    - 其他字段从配置/环境变量来
    """
    cpu_pct = random.randint(5, 80)
    mem_pct = random.randint(10, 90)

    payload = {
        "sn": SN,
        "wan_ip": WAN_IP,
        "sw_version": SW_VERSION,
        "cpu_pct": cpu_pct,
        "mem_pct": mem_pct,
        "host": get_hostname(),
        "ts": int(time.time() * 1000),
    }
    return payload


def sign_body(body_bytes: bytes) -> str:
    """
    用与后端约定的 shared secret 做 HMAC-SHA256，
    放在 X-Cpemon-Signature 头里，后端可以用同样算法验签。
    """
    mac = hmac.new(SHARED_SECRET.encode("utf-8"), body_bytes, hashlib.sha256)
    return mac.hexdigest()


def send_heartbeat():
    payload = build_payload()
    # 用紧凑 JSON，方便后端复算签名
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    signature = sign_body(body)

    headers = {
        "Content-Type": "application/json",
        "X-Cpemon-Signature": signature,
    }

    try:
        resp = requests.post(
            API_URL,
            data=body,
            headers=headers,
            timeout=5,
            verify=VERIFY_SSL,
        )
        print(
            f"[OK] sent heartbeat sn={payload['sn']} "
            f"cpu={payload['cpu_pct']} mem={payload['mem_pct']} "
            f"status={resp.status_code}"
        )
    except Exception as e:
        print(f"[ERR] failed to send heartbeat: {e}")


def main():
    print(
        f"Starting CPE heartbeat simulator "
        f"→ {API_URL}, sn={SN}, interval={INTERVAL}s, ssl_verify={VERIFY_SSL}"
    )
    while True:
        send_heartbeat()
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
