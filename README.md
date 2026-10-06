# Suricata IDS Practical Lab

A beginner-friendly, authorized cybersecurity lab for installing Suricata, identifying a monitored interface, creating a custom IDS rule, generating test traffic with Netcat, and analyzing alerts in `fast.log` and `eve.json`.

> **Authorization:** Run this lab only on systems, virtual machines, networks, and traffic you own or have explicit permission to test. The traffic generation is intentionally simple and local to an isolated lab.

## Learning objectives
By the end of this lab you should be able to:
- Install and verify Suricata.
- Identify the correct monitoring interface.
- Understand the basic Suricata configuration and rule path.
- Write and load a custom detection rule.
- Generate authorized TCP test traffic with Netcat.
- Start Suricata in IDS mode and verify packet capture.
- Trigger and inspect alerts in `fast.log` and `eve.json`.
- Use `grep` and `jq` to filter JSON alerts.
- Troubleshoot common interface, routing, listener, and rule-loading problems.

## Lab topology

```text
                 Isolated / Authorized Lab Network
       +----------------------+       +----------------------+
       | Client VM            |       | Suricata Sensor VM   |
       | <CLIENT_IP>          | ----> | <SURICATA_IP>        |
       | Netcat traffic       |       | <INTERFACE>          |
       +----------------------+       +----------------------+
                  TCP test traffic / alert
```

The sensor should observe the traffic on `<INTERFACE>`. Replace placeholders with values from your lab.

## Prerequisites
- Linux VM for the Suricata sensor (Ubuntu/Debian commands are used below).
- Optional second Linux VM for the client.
- Administrative privileges (`sudo`).
- Network connectivity between the VMs.
- `suricata`, `jq`, and `netcat`/`nc`.
- A terminal and permission to capture traffic on the selected interface.

## 1. Install Suricata

```bash
sudo apt update
sudo apt install -y suricata jq netcat-openbsd
suricata --build-info
```

**Expected:** package installation completes; `suricata --build-info` prints version/build information.

Check the service:

```bash
sudo systemctl status suricata --no-pager
```

The service may be inactive until configured. That is not automatically an error.

## 2. Identify the network interface

On the Suricata sensor:

```bash
ip -br addr
ip route
```

Look for the interface carrying traffic from `<CLIENT_IP>` to `<SURICATA_IP>`. Set the placeholder:

```bash
export INTERFACE=<INTERFACE>
```

Confirm:

```bash
ip addr show "$INTERFACE"
```

If the sensor is a VM with multiple NICs, verify which NIC is attached to the intended lab network.

## 3. Verify connectivity

From the client:

```bash
ping -c 3 <SURICATA_IP>
```

From the sensor:

```bash
ping -c 3 <CLIENT_IP>
```

If ICMP is blocked in your lab, use a TCP test port instead.

## 4. Create the custom detection rule

Create/edit:

```bash
sudo nano /etc/suricata/rules/local.rules
```

Add:

```text
alert tcp any any -> any 4444 (msg:"LAB TEST - TCP 4444 connection detected"; flags:S; sid:1000001; rev:1;)
```

This detects TCP SYN packets destined for port 4444. It is intentionally narrow and designed for this lab.

Verify the rule exists:

```bash
sudo grep -n "LAB TEST" /etc/suricata/rules/local.rules
```

## 5. Configure Suricata

First make a backup:

```bash
sudo cp /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bak
```

Open the configuration:

```bash
sudo nano /etc/suricata/suricata.yaml
```

Ensure the `HOME_NET` setting represents the lab network, and ensure `rule-files` includes:

```yaml
rule-files:
  - suricata.rules
  - local.rules
```

If your distribution's configuration differs, preserve its existing rule file entries and add `local.rules` rather than replacing the whole section.

For a simple lab, the command-line `-i` option below explicitly selects the interface, reducing ambiguity.

Validate configuration/rules:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

**Expected:** a successful configuration test ending with wording equivalent to `Configuration provided was successfully loaded` / `...successful...`.

If your installed Suricata version reports a rule-loading issue, inspect the preceding error and fix the referenced file/path.

## 6. Prepare log files

```bash
sudo mkdir -p /var/log/suricata
sudo touch /var/log/suricata/fast.log /var/log/suricata/eve.json
sudo tail -n 5 /var/log/suricata/fast.log
```

Do not expect alerts yet.

## 7. Generate authorized Netcat traffic

### Option A: TCP listener on the Suricata sensor

On the sensor:

```bash
nc -lvnp 4444
```

**Expected:** Netcat reports that it is listening on TCP port 4444.

From the client:

```bash
nc -vz <SURICATA_IP> 4444
```

**Expected:** a successful TCP connection if the path/firewall permits it. The connection attempt generates a SYN packet that should match the rule.

### Option B: If Netcat syntax differs

Run:

```bash
nc -h
```

Use the equivalent listen/connect syntax supplied by your installed Netcat package. Do not change the destination port from 4444 unless you also change the rule.

## 8. Start Suricata

For an interactive lab test:

```bash
sudo suricata -c /etc/suricata/suricata.yaml -i "$INTERFACE" -l /var/log/suricata
```

Leave this running.

In another terminal, verify packets/log activity:

```bash
sudo tail -f /var/log/suricata/fast.log
```

And, separately:

```bash
sudo tail -f /var/log/suricata/eve.json
```

Trigger the Netcat connection from the client again.

Stop the foreground Suricata process with `Ctrl+C` after testing.

### Service-based alternative

If you have configured the distribution's service interface correctly:

```bash
sudo systemctl restart suricata
sudo systemctl status suricata --no-pager
```

For this beginner lab, foreground `-i` testing is preferred because it makes interface selection visible.

## 9. Analyze fast.log

Search for the lab alert:

```bash
sudo grep -n "LAB TEST" /var/log/suricata/fast.log
```

Expected pattern:

```text
... [**] [1:1000001:1] LAB TEST - TCP 4444 connection detected [**] ...
```

Exact timestamps, IPs, ports, and formatting will vary.

## 10. Analyze eve.json with grep

```bash
sudo grep '"event_type":"alert"' /var/log/suricata/eve.json | tail -n 5
```

Narrow it to the custom signature:

```bash
sudo grep '1000001' /var/log/suricata/eve.json | tail -n 5
```

## 11. Analyze eve.json with jq

Readable alert objects:

```bash
sudo jq 'select(.event_type=="alert")' /var/log/suricata/eve.json | tail -n 1
```

Extract useful fields:

```bash
sudo jq -r '
  select(.event_type=="alert") |
  [.timestamp, .src_ip, .src_port, .dest_ip, .dest_port,
   .alert.signature_id, .alert.signature] | @tsv
' /var/log/suricata/eve.json | tail -n 10
```

**Expected:** tab-separated timestamp, source, destination, SID, and signature. Field availability can vary slightly by Suricata version/output configuration.

## Expected result

A successful run produces a custom alert for SID `1000001` when the client attempts TCP port `4444` on the sensor.

The important evidence is:
1. Suricata configuration test succeeds.
2. The selected interface is correct.
3. Netcat creates a TCP connection attempt.
4. `fast.log` contains the custom signature.
5. `eve.json` contains an `alert` event with SID `1000001`.

## Troubleshooting

### `No route to host`
Check addressing and routes:

```bash
ip -br addr
ip route
ping -c 3 <SURICATA_IP>
```

Confirm both VMs are attached to the same intended lab network and that host/VM firewalls are not blocking the path.

### `Connection refused`
This usually means nothing is listening on port 4444, or a firewall actively rejected the connection.

On the sensor:

```bash
sudo ss -lntp | grep ':4444'
```

Start the listener:

```bash
nc -lvnp 4444
```

Then retry from the client.

### Wrong interface
Compare:

```bash
ip route get <CLIENT_IP>
ip -br addr
```

The interface shown for the route is a strong candidate for `<INTERFACE>`. Confirm it matches the VM NIC connected to the lab network.

Run Suricata explicitly:

```bash
sudo suricata -c /etc/suricata/suricata.yaml -i <INTERFACE> -l /var/log/suricata
```

### No alerts
Work through this order:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
sudo grep -n "1000001" /etc/suricata/rules/local.rules
sudo tcpdump -ni <INTERFACE> tcp port 4444
sudo tail -n 20 /var/log/suricata/fast.log
```

If `tcpdump` sees no packets, fix the network/interface problem first. If packets are visible but no alert appears, verify the rule is loaded and that the traffic is actually destined for TCP port 4444.

### Rule not loading
Check syntax and configuration:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
sudo grep -n "local.rules" /etc/suricata/suricata.yaml
```

Keep the SID unique in your lab. `1000001` is used here as a lab SID.

## Verification checklist

- [ ] Suricata installed and version verified.
- [ ] `<INTERFACE>` identified.
- [ ] `<CLIENT_IP>` and `<SURICATA_IP>` confirmed.
- [ ] `local.rules` contains SID `1000001`.
- [ ] `suricata -T` succeeds.
- [ ] Netcat listener is active on 4444.
- [ ] Client can reach the sensor.
- [ ] Suricata is capturing on the intended interface.
- [ ] `fast.log` contains the lab alert.
- [ ] `eve.json` contains an alert event.
- [ ] `grep` and `jq` were used to extract evidence.

## Student questions

1. What is the difference between an IDS alert and a firewall block?
2. Why is selecting the correct interface important?
3. What does the `sid` field identify?
4. What does `flags:S` match in this rule?
5. Why might `tcpdump` show traffic while Suricata produces no alert?
6. What information is easier to extract from `eve.json` than from `fast.log`?
7. How would you modify the rule to monitor another authorized lab port?

## Practical challenge

Create a second custom rule for an authorized test port of your choice, generate traffic to that port with Netcat, and produce evidence showing:
- the rule file entry;
- successful Suricata configuration testing;
- the traffic-generation command;
- the resulting `fast.log` alert;
- a filtered `jq` output from `eve.json`.

Do not use public systems or third-party networks.

## Suggested evidence

Store screenshots or text evidence in `evidence/`. A sample alert is provided only as a format example; it is not live evidence from your environment.

## Portfolio notes

For GitHub, include your own screenshots and sanitized outputs. Remove usernames, public IP addresses, tokens, private hostnames, and other sensitive data before publishing.
