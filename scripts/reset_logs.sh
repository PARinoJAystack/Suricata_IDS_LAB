#!/usr/bin/env bash
# =============================================================================
# reset_logs.sh - Empty Suricata fast.log and eve.json between test runs.
# Usage: sudo ./scripts/reset_logs.sh      (LAB USE ONLY - destroys log data)
# =============================================================================
set -euo pipefail
LOG_DIR="${1:-/var/log/suricata}"
[[ $EUID -eq 0 ]] || { echo "[!] Run with sudo."; exit 1; }
read -r -p "Empty fast.log and eve.json in ${LOG_DIR}? (yes/no): " ans
[[ "$ans" == "yes" ]] || { echo "Aborted."; exit 1; }
truncate -s 0 "${LOG_DIR}/fast.log" "${LOG_DIR}/eve.json"
echo "[+] Logs emptied. Suricata keeps writing to the same files."
