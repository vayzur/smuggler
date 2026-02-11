# Operations

## Service Management

Smuggler creates systemd services for every component. Service names follow a consistent pattern so you can manage them without looking anything up.

### Tunnel services

```bash
# Start / stop / restart a tunnel
systemctl start smuggler@tun0
systemctl stop smuggler@tun0
systemctl restart smuggler@tun0

# View status and recent logs
systemctl status smuggler@tun0
journalctl -u smuggler@tun0 -f

# Check all tunnel services at once
systemctl list-units 'smuggler@*'
```

### Health check services

```bash
# Health check timer (runs the checker on interval)
systemctl status health-smuggler@tun0.timer

# Trigger a health check manually right now
systemctl start health-smuggler@tun0.service

# Watch health check logs
journalctl -u health-smuggler@tun0.service -f
```

### SSH proxy services

```bash
systemctl status ssh-proxy@tun0-p1
journalctl -u ssh-proxy@tun0-p1 -f
```

### DNSdist (load balancing)

```bash
# Client or server side DNSdist
systemctl status dnsdist
journalctl -u dnsdist -f
```

---

## Deploying

```bash
# Full deployment
ansible-playbook -i inventory/hosts.yml smuggler.yml

# Target only client nodes
ansible-playbook -i inventory/hosts.yml smuggler.yml --limit client_nodes

# Target only server nodes
ansible-playbook -i inventory/hosts.yml smuggler.yml --limit server_nodes

# Dry run (check what would change)
ansible-playbook -i inventory/hosts.yml smuggler.yml --check
```

---

## Updating a tunnel

Edit `inventory/group_vars/all/tunnels.yml` and re-run the playbook. Smuggler will update the systemd unit files and restart affected services.

---

## Removing a tunnel

Smuggler has no delete tasks. To remove a tunnel:

1. Stop the service on the target node:
   ```bash
   systemctl stop smuggler@tun0
   systemctl disable smuggler@tun0
   ```

2. Remove the unit file:
   ```bash
   rm /etc/systemd/system/smuggler@tun0.service
   systemctl daemon-reload
   ```

3. If health checking was enabled, also remove:
   ```bash
   systemctl stop health-smuggler@tun0.timer
   systemctl disable health-smuggler@tun0.timer
   rm /etc/systemd/system/health-smuggler@tun0.service
   rm /etc/systemd/system/health-smuggler@tun0.timer
   systemctl daemon-reload
   ```

4. Remove the tunnel from `tunnels.yml` so re-running the playbook doesn't recreate it.

---

## Checking tunnel connectivity

Quick test — use the tunnel as an HTTP proxy and hit a URL:

```bash
curl -x http://127.0.0.1:5200 http://www.google.com/gen_204 -v
```

Or SOCKS5:

```bash
curl -x socks5://127.0.0.1:5200 http://www.google.com/gen_204 -v
```

A `204 No Content` response means the tunnel is working.

---

## Logs

All Smuggler services log through systemd journal. Useful flags:

```bash
# Follow in real time
journalctl -u smuggler@tun0 -f

# Show last 100 lines
journalctl -u smuggler@tun0 -n 100

# Since last boot
journalctl -u smuggler@tun0 -b

# All Smuggler services together
journalctl -u 'smuggler@*' -f
```

dnstt logs are filtered to warnings and above to reduce noise. You can change this by editing the systemd unit's `LogLevelMax` if needed.
