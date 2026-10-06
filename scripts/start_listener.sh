#!/usr/bin/env bash
# =============================================================================
# start_listener.sh - Start a netcat listener on the SURICATA SENSOR VM.
# Usage: ./scripts/start_listener.sh [PORT]      (default port: 4444)
# Press Ctrl+C to stop. Authorized lab use only.
# =============================================================================
set -uo pipefail
PORT="${1:-4444}"

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "[!] Invalid port: $PORT"; exit 1
fi
if (( PORT < 1024 )) && [[ $EUID -ne 0 ]]; then
  echo "[!] Ports below 1024 need root. Use a port >= 1024 (default 4444)."; exit 1
fi

trap 'echo; echo "[*] Listener stopped."; exit 0' INT TERM

if command -v ncat >/dev/null 2>&1; then
  echo "[*] Listening on TCP/${PORT} with ncat (stays open for many connections)..."
  ncat -lvkp "$PORT"
else
  echo "[*] Listening on TCP/${PORT} with nc (re-listens after each connection)..."
  while true; do
    nc -lvnp "$PORT"
    sleep 0.2
  done
fi
