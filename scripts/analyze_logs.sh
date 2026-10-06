#!/usr/bin/env bash
# =============================================================================
# analyze_logs.sh - Summarize Suricata alerts from fast.log and eve.json.
# Usage: sudo ./scripts/analyze_logs.sh [LOG_DIR]     (default /var/log/suricata)
# Requires: grep, jq
# =============================================================================
set -uo pipefail
LOG_DIR="${1:-/var/log/suricata}"
FAST="${LOG_DIR}/fast.log"
EVE="${LOG_DIR}/eve.json"

[[ -r "$FAST" ]] || { echo "[!] Cannot read $FAST (try sudo, or check the path)"; exit 1; }
[[ -r "$EVE"  ]] || { echo "[!] Cannot read $EVE (try sudo, or check the path)"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "[!] jq not installed: sudo apt install jq"; exit 1; }

echo "=== 1. Lab alerts in fast.log (messages starting with 'LAB') ==="
echo -n "Total: "; grep -c "LAB " "$FAST" || true
echo
echo "=== 2. Alert count per signature (fast.log) ==="
grep -o '\[\*\*\] \[1:[0-9]*:[0-9]*\] [^[]*' "$FAST" | sort | uniq -c | sort -rn
echo
echo "=== 3. Last 5 alerts (fast.log) ==="
tail -n 5 "$FAST"
echo
echo "=== 4. Alert table from eve.json (time, src -> dst, SID, signature) ==="
jq -r 'select(.event_type=="alert")
       | [.timestamp, "\(.src_ip):\(.src_port) -> \(.dest_ip):\(.dest_port)",
          .alert.signature_id, .alert.signature] | @tsv' "$EVE" | tail -n 10
echo
echo "=== 5. Payloads that matched SID 1000002 ==="
jq -r 'select(.alert.signature_id==1000002) | .payload_printable' "$EVE" | tail -n 5
echo
echo "=== 6. Event types seen in eve.json ==="
jq -r '.event_type' "$EVE" | sort | uniq -c | sort -rn
