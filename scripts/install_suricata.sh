#!/usr/bin/env bash
# =============================================================================
# install_suricata.sh - Install Suricata + tools and deploy the lab rules.
# Run on the SURICATA SENSOR VM (Ubuntu/Debian based). Authorized lab use only.
#
# Usage:  ./scripts/install_suricata.sh [--ppa]
#   --ppa   (Ubuntu only) use the OISF stable PPA for a newer Suricata version
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_SRC="${REPO_DIR}/rules/local.rules"
RULES_DST="/var/lib/suricata/rules/local.rules"
YAML="/etc/suricata/suricata.yaml"

[[ -f "$RULES_SRC" ]] || { echo "[!] Cannot find $RULES_SRC"; exit 1; }

echo "[*] Updating package lists..."
sudo apt update

if [[ "${1:-}" == "--ppa" ]]; then
  echo "[*] Adding OISF stable PPA (Ubuntu only)..."
  sudo apt install -y software-properties-common
  sudo add-apt-repository -y ppa:oisf/suricata-stable
  sudo apt update
fi

echo "[*] Installing suricata, jq and netcat..."
sudo apt install -y suricata jq netcat-openbsd

echo "[*] Stopping the auto-started service (we will run Suricata manually)..."
sudo systemctl stop suricata 2>/dev/null || true

echo "[*] Backing up ${YAML}..."
if [[ ! -f "${YAML}.bak" ]]; then
  sudo cp "$YAML" "${YAML}.bak"
fi

echo "[*] Deploying local.rules to ${RULES_DST}..."
sudo mkdir -p "$(dirname "$RULES_DST")"
sudo cp "$RULES_SRC" "$RULES_DST"

echo
suricata -V || true
echo
cat <<'NEXT'
[+] Done. NEXT STEPS (manual - see Section 4 of the lab manual):
    1. Find your interface:   ip -br a
    2. Edit /etc/suricata/suricata.yaml  (HOME_NET, af-packet interface, rule-files)
       Reference: config/suricata.yaml.example
    3. Validate:              sudo suricata -T -c /etc/suricata/suricata.yaml -v
NEXT
