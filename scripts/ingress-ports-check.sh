#!/usr/bin/env bash
set -euo pipefail
echo "[*] Checking 80/443 listeners (may require sudo)..."
if command -v ss >/dev/null 2>&1; then
  sudo ss -ltnp '( sport = :80 or sport = :443 )' || ss -ltnp '( sport = :80 or sport = :443 )'
else
  sudo netstat -lntp | egrep ':80|:443' || true
fi
