# Suricata IDS Lab - Command Cheat Sheet

> **Placeholders:** replace `<SURICATA_IP>`, `<CLIENT_IP>`, `<INTERFACE>` and `<LAB_SUBNET>` with your own lab values. Authorized lab use only.

## Find your network details (both VMs)

| Task | Command |
|---|---|
| List interfaces and IPs | `ip -br a` |
| Show routes | `ip route` |
| Interface used to reach the client | `ip route get <CLIENT_IP>` |
| Bring an interface up | `sudo ip link set <INTERFACE> up` |
| Test connectivity | `ping -c 3 <SURICATA_IP>` |

## Install and configure (Sensor VM)

| Task | Command |
|---|---|
| Install | `sudo apt update && sudo apt install -y suricata jq netcat-openbsd` |
| Check version | `suricata -V` |
| Stop auto-started service | `sudo systemctl stop suricata` |
| Back up config | `sudo cp /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bak` |
| Download standard rules | `sudo suricata-update` |
| Install lab rules | `sudo cp rules/local.rules /var/lib/suricata/rules/local.rules` |
| Edit config | `sudo nano /etc/suricata/suricata.yaml` |
| Validate config and rules | `sudo suricata -T -c /etc/suricata/suricata.yaml -v` |

## Run Suricata (Sensor VM)

| Task | Command |
|---|---|
| Start in IDS mode | `sudo suricata -c /etc/suricata/suricata.yaml -i <INTERFACE>` |
| Start, checksums off (VM quirk) | `sudo suricata -c /etc/suricata/suricata.yaml -i <INTERFACE> -k none` |
| Reload rules live | `sudo kill -USR2 $(pidof suricata)` |
| Is Suricata running? | `pidof suricata` |
| Stop Suricata | `Ctrl+C` in its terminal, or `sudo pkill suricata` |
| Engine messages and errors | `sudo tail -n 30 /var/log/suricata/suricata.log` |

## Netcat traffic

| Task | Command |
|---|---|
| Listener (Sensor) | `nc -lvnp 4444` |
| Auto-restarting listener | `./scripts/start_listener.sh 4444` |
| Check the listener port | `ss -ltnp \| grep 4444` |
| Connection attempt (Client) | `nc -zv -w 2 <SURICATA_IP> 4444` |
| Send marker payload (Client) | `printf 'SURICATA-LAB-TEST hello\n' \| nc -w 3 <SURICATA_IP> 4444` |
| All test traffic (Client) | `./scripts/generate_traffic.sh <SURICATA_IP> 4444` |
| Prove packets arrive | `sudo tcpdump -i <INTERFACE> -n port 4444 -c 5` |

## Read fast.log with grep

| Task | Command |
|---|---|
| Watch alerts live | `sudo tail -f /var/log/suricata/fast.log` |
| Lab alerts only | `sudo grep "LAB " /var/log/suricata/fast.log` |
| One signature | `sudo grep "1000002" /var/log/suricata/fast.log` |
| Count alerts | `sudo grep -c "LAB Netcat" /var/log/suricata/fast.log` |
| One source IP, priority 1 | `sudo grep "<CLIENT_IP>" /var/log/suricata/fast.log \| grep "Priority: 1"` |
| Alerts per signature | `sudo grep -o '\[1:[0-9]*:[0-9]*\] [^[]*' /var/log/suricata/fast.log \| sort \| uniq -c \| sort -rn` |

## Analyze eve.json with jq

| Task | Command |
|---|---|
| Event types present | `sudo jq -r '.event_type' /var/log/suricata/eve.json \| sort \| uniq -c` |
| All alerts (pretty) | `sudo jq 'select(.event_type=="alert")' /var/log/suricata/eve.json` |
| Alerts by one SID | `sudo jq 'select(.alert.signature_id==1000002)' /var/log/suricata/eve.json` |
| Payload text | `sudo jq -r 'select(.alert.signature_id==1000002) \| .payload_printable' /var/log/suricata/eve.json` |
| Source IP and signature | `sudo jq -r 'select(.event_type=="alert") \| [.src_ip, .alert.signature] \| @tsv' /var/log/suricata/eve.json` |
| Alerts from one IP | `sudo jq 'select(.event_type=="alert" and .src_ip=="<CLIENT_IP>")' /var/log/suricata/eve.json` |
| Full summary report | `sudo ./scripts/analyze_logs.sh` |
| Empty logs between runs | `sudo ./scripts/reset_logs.sh` |

## Rule syntax at a glance

```text
alert tcp any any -> any 4444 (msg:"text"; content:"STRING"; nocase; sid:1000002; rev:1;)
```

| Part | Meaning |
|---|---|
| `alert` | Action: log an alert (IDS mode). |
| `tcp` / `udp` / `icmp` | Protocol to inspect. |
| `any any -> any 4444` | Source IP and port, direction, destination IP and port. |
| `content:"..."` / `nocase` | Search the payload, ignoring case. |
| `flags:S` | Match the TCP SYN flag. |
| `sid` / `rev` | Unique rule ID (1000000 and above) and revision. |

## Log files (/var/log/suricata/)

| File | Contains |
|---|---|
| `fast.log` | One-line text alerts. |
| `eve.json` | Rich JSON events: alerts, flows, stats. |
| `suricata.log` | Engine messages and errors. |
| `stats.log` | Performance counters. |

## Quick troubleshooting

| Symptom | First checks |
|---|---|
| No route to host | Wrong IP or network, adapter down, firewall (`sudo ufw status`). |
| Connection refused | No listener: restart `nc -lvnp 4444`. Rule 1000001 still fires. |
| No alerts | Wrong interface (`ip route get <CLIENT_IP>`), rules not loaded (`suricata -T`), rule not in `rule-files`. |
| Rules failed to load | Check for a missing `;` or `)`, or a duplicate `sid`. |
| Alerts after edit missing | Copy the rule file again, then `sudo kill -USR2 $(pidof suricata)`. |
| Permission denied on logs | Use `sudo`. |
