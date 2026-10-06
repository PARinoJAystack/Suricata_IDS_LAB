# Troubleshooting Guide

> Extracted from Section 12 of [LAB_MANUAL.md](LAB_MANUAL.md). "Section" references point to that manual. Replace `<SURICATA_IP>`, `<CLIENT_IP>` and `<INTERFACE>` with your own lab values.

Work through the matching section in order. Most problems come from the network, the interface or the rule load.

## 1. No route to host

Example error on the client:

```output
nc: connect to 192.168.56.10 port 4444 (tcp) failed: No route to host
```

**Meaning:** The client cannot reach the sensor at layer 2 or 3, or something actively rejected the packet.

| Likely cause | How to check | Fix |
|---|---|---|
| Wrong IP address | `ip -br a` on the sensor | Use the sensor's real lab IP as `<SURICATA_IP>`. |
| VMs on different networks | VirtualBox Settings > Network | Put both VMs on the same Host-only/Internal network. |
| Adapter not up | `ip -br a` shows `DOWN` or no address | `sudo ip link set <INTERFACE> up`, then renew DHCP or set a static IP. |
| Different subnets | Compare the two `ip -br a` outputs | Give both VMs addresses in the same subnet. |
| Firewall rejecting | `sudo ufw status` on the sensor | `sudo ufw allow from <CLIENT_IP> to any port 4444 proto tcp` or `sudo ufw disable` in the lab. |

Quick test: `ping -c 3 <SURICATA_IP>`. If ping fails too, fix networking first.

## 2. Connection refused

Example error on the client:

```output
nc: connect to 192.168.56.10 port 4444 (tcp) failed: Connection refused
```

**Meaning:** The sensor is reachable, but **nothing is listening** on port 4444.

| Likely cause | How to check | Fix |
|---|---|---|
| Listener not started | `ss -ltnp \| grep 4444` on the sensor | Start `nc -lvnp 4444`. |
| Listener already closed | Plain `nc -l` exits after one connection | Restart it, or use `./scripts/start_listener.sh`. |
| Wrong port | Compare the ports on both sides | Use 4444 on both. |
| Listener bound elsewhere | `ss -ltnp` shows `127.0.0.1:4444` | Listen on all interfaces: `nc -lvnp 4444`. |

> **Tip:** A "Connection refused" attempt **still triggers rule 1000001**. The SYN reached the sensor before being refused, so Suricata sees it. This is a great way to confirm that detection works even without a listener.

## 3. Wrong interface

**Symptoms:** Suricata starts normally, but no alerts appear for traffic you know was sent.

1. Find the interface that carries the traffic:

```bash
ip route get <CLIENT_IP>
```

Expected output:

```output
192.168.56.20 dev enp0s8 src 192.168.56.10 uid 1000
```

2. The `dev` value (`enp0s8` here) must match the `-i <INTERFACE>` you used (or `af-packet` in the YAML).
3. Prove packets arrive on that interface with tcpdump (run while the client pings or sends traffic):

```bash
sudo tcpdump -i <INTERFACE> -n port 4444 -c 5
```

If tcpdump shows packets but Suricata raises no alerts, the problem is in the rules (Section 12.4). If tcpdump shows nothing, the traffic is arriving on another interface or not at all.

4. **Single-VM mode:** traffic from the VM to itself travels over `lo`. Use `-i lo` and send to `127.0.0.1`.
5. Do not use the NAT adapter (for example `enp0s3`) unless your traffic actually goes through it.

## 4. Missing alerts

Check these in order:

| # | Check | Command | Healthy result |
|---|---|---|---|
| 1 | Suricata is running | `pidof suricata` | A process ID is printed. |
| 2 | Right interface | Section 12.3 | `dev` matches `-i`. |
| 3 | Rules loaded | `sudo grep -i "rules" /var/log/suricata/suricata.log \| tail -n 3` | `rules successfully loaded`, `0 rules failed`. |
| 4 | local.rules is in rule-files | `sudo grep -n "local.rules" /etc/suricata/suricata.yaml` | A `- local.rules` line is shown. |
| 5 | Rule file is in place | `ls /var/lib/suricata/rules/local.rules` | The file exists. |
| 6 | SID is unique | `grep -c "sid:1000002" /var/lib/suricata/rules/local.rules` | `1` |
| 7 | Traffic matches the rule | Port is 4444 and text is `SURICATA-LAB-TEST` | Exactly as written. |
| 8 | Logs are being written | `sudo ls -l /var/log/suricata/` | Recent timestamps. |
| 9 | You edited the rule after starting | Section 6.3 | Reload or restart Suricata. |

Other causes and fixes:

- **Rules failed to load:** run `sudo suricata -T -c /etc/suricata/suricata.yaml -v` and read the error. Typical mistakes are a missing semicolon, a missing closing parenthesis or a duplicate `sid`.
- **Still running as a service:** the service and your manual run may conflict. Stop the service: `sudo systemctl stop suricata`.
- **Checksum offloading (VM networking quirk):** Suricata may ignore packets with unverified checksums. Test with checksum checks disabled: `sudo suricata -c /etc/suricata/suricata.yaml -i <INTERFACE> -k none`
- **Looking at the wrong file:** read `/var/log/suricata/fast.log`, not an old copy in your project folder.
- **No `sudo` on logs:** `cat` on the log may fail with *Permission denied*. Use `sudo`.
- **Too much noise from the full rule set:** filter on your own rules: `sudo grep "LAB " /var/log/suricata/fast.log`.

## 5. Other common errors

| Error | Cause | Fix |
|---|---|---|
| `E: Unable to locate package suricata` | Package lists are out of date | `sudo apt update`, or add the OISF PPA (Section 4.2). |
| `sudo: Sorry, try again.` | Wrong sudo password | Use the VM user's password. Check the lab instructions. |
| `Permission denied` opening the interface | Not running as root | Use `sudo suricata ...`. |
| `yaml: ... did not find expected key` | YAML indentation or a tab character | Use spaces only. Restore the backup: `sudo cp /etc/suricata/suricata.yaml.bak /etc/suricata/suricata.yaml` |
| `Address already in use` (nc) | Another listener on 4444 | `ss -ltnp \| grep 4444`, then stop that process. |
| `suricata.rules: No such file` | `suricata-update` was never run | Run it, or remove `suricata.rules` from `rule-files`. |
| `jq: parse error` | Using `jq` on `fast.log` | `jq` works only on `eve.json`. |
