#!/usr/bin/env bash
set -euo pipefail

SURICATA_IP="${1:-<SURICATA_IP>}"
PORT="${2:-4444}"

echo "[*] Authorized lab traffic test: ${SURICATA_IP}:${PORT}"
echo "[*] Run a listener on the Suricata sensor first:"
echo "    nc -lvnp ${PORT}"
echo
echo "[*] Press Enter to generate the connection attempt."
read -r
nc -vz "${SURICATA_IP}" "${PORT}"
