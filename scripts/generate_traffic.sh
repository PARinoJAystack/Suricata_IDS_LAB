#!/usr/bin/env bash
# =============================================================================
# generate_traffic.sh - Generate harmless test traffic from the CLIENT VM.
# Usage: ./scripts/generate_traffic.sh <SURICATA_IP> [PORT]
#   e.g. ./scripts/generate_traffic.sh 192.168.56.10 4444
#
# SAFETY: only private/lab addresses are accepted (10.x, 172.16-31.x,
# 192.168.x, 127.x). Use ONLY on systems you own or are authorized to test.
# =============================================================================
set -uo pipefail

TARGET="${1:-}"
PORT="${2:-4444}"
MARKER="SURICATA-LAB-TEST"

usage() { echo "Usage: $0 <SURICATA_IP> [PORT]"; exit 1; }
[[ -n "$TARGET" ]] || usage

# --- validate IPv4 -----------------------------------------------------------
if ! [[ "$TARGET" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
  echo "[!] '$TARGET' is not a valid IPv4 address. Did you leave the <SURICATA_IP> placeholder?"
  exit 1
fi
o1=${BASH_REMATCH[1]}; o2=${BASH_REMATCH[2]}; o3=${BASH_REMATCH[3]}; o4=${BASH_REMATCH[4]}
for o in "$o1" "$o2" "$o3" "$o4"; do
  (( 10#$o <= 255 )) || { echo "[!] Invalid octet in $TARGET"; exit 1; }
done
o1=$((10#$o1)); o2=$((10#$o2))

private=false
(( o1 == 10 )) && private=true
(( o1 == 172 && o2 >= 16 && o2 <= 31 )) && private=true
(( o1 == 192 && o2 == 168 )) && private=true
(( o1 == 127 )) && private=true
if [[ "$private" != true ]]; then
  echo "[!] $TARGET is not a private/lab address. Refusing to send traffic."
  exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "[!] Invalid port: $PORT"; exit 1
fi
command -v nc >/dev/null 2>&1 || { echo "[!] nc (netcat) is not installed."; exit 1; }

# --- authorization prompt ------------------------------------------------------
if [[ "${AUTHORIZED:-}" != "yes" ]]; then
  read -r -p "Confirm $TARGET is YOUR authorized lab system (type 'yes'): " ans
  [[ "$ans" == "yes" ]] || { echo "Aborted."; exit 1; }
fi

echo
echo "[1/3] ICMP echo (ping) -> triggers SID 1000003"
ping -c 3 -W 2 "$TARGET" || echo "[!] Ping failed (ICMP may be blocked). Continuing."

echo
echo "[2/3] TCP connection attempt to ${TARGET}:${PORT} -> triggers SID 1000001"
nc -zv -w 2 "$TARGET" "$PORT" || echo "[i] Connection failed (no listener?) - the SYN was still sent."
# A plain 'nc -l' listener serves ONE connection, then must restart. Give it time.
sleep 2

echo
echo "[3/3] Payload with marker '${MARKER}' -> triggers SID 1000002"
printf '%s hello from client\n' "$MARKER" | nc -w 3 "$TARGET" "$PORT" \
  || echo "[!] Payload send failed. Is the listener running on ${TARGET}:${PORT}?"

echo
echo "[+] Done. On the Suricata VM run:  tail -n 5 /var/log/suricata/fast.log"
