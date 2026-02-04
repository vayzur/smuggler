# Operations & Monitoring

This guide covers day-to-day tunnel management and monitoring.

## Service Management

Each tunnel runs as an independent systemd service named `smuggler@<name>.service`.

### Basic Commands
```bash
# Check status
systemctl status smuggler@tun0

# Start
systemctl start smuggler@tun0

# Stop
systemctl stop smuggler@tun0

# Restart
systemctl restart smuggler@tun0

# Enable (start on boot)
systemctl enable smuggler@tun0

# Disable (don't start on boot)
systemctl disable smuggler@tun0
```

### Managing Multiple Tunnels
```bash
# Status of all tunnels
systemctl status 'smuggler@*'

# Start all tunnels
systemctl start 'smuggler@*'

# Stop all tunnels
systemctl stop 'smuggler@*'

# Restart all tunnels
systemctl restart 'smuggler@*'

# List all tunnel services
systemctl list-units 'smuggler@*'
```

### Service Status Indicators

| Status | Description | Action |
|--------|-------------|--------|
| `active (running)` | Tunnel operational | None needed |
| `inactive (dead)` | Tunnel stopped | Start if needed |
| `failed` | Tunnel crashed | Check logs, investigate |
| `activating (auto-restart)` | Restarting after crash | Monitor |

## Log Management

### Viewing Logs
```bash
# Real-time logs (follow)
journalctl -u smuggler@tun0 -f

# Last 100 lines
journalctl -u smuggler@tun0 -n 100

# Logs from last hour
journalctl -u smuggler@tun0 --since "1 hour ago"

# Logs from specific time range
journalctl -u smuggler@tun0 --since "2024-01-01 00:00" --until "2024-01-02 00:00"

# All tunnel logs
journalctl -u 'smuggler@*' -f

# Export logs to file
journalctl -u smuggler@tun0 > tunnel_logs.txt
```

### Log Filtering
```bash
# Show only errors
journalctl -u smuggler@tun0 -p err

# Show warnings and above
journalctl -u smuggler@tun0 -p warning

# Grep for specific errors
journalctl -u smuggler@tun0 | grep -i "error\|fail\|timeout"

# Show kernel messages related to tunnels
journalctl -k | grep tun
```

### Log Rotation

Logs are automatically rotated by systemd:
```bash
# Check disk usage
journalctl --disk-usage

# Vacuum logs older than 7 days
journalctl --vacuum-time=7d

# Vacuum logs to max 500MB
journalctl --vacuum-size=500M

# Verify log rotation config
cat /etc/systemd/journald.conf
```

## Monitoring

### Connection Monitoring
```bash
# Active connections per tunnel
sudo netstat -tn | grep :7000

# Connection count
sudo netstat -tn | grep :7000 | wc -l

# Connections with state
sudo netstat -tn | grep :7000 | awk '{print $6}' | sort | uniq -c

# Monitor in real-time
watch -n 1 'sudo netstat -tn | grep ":808[0-9]" | wc -l'
```

### Network Traffic
```bash
# Install iftop if needed
sudo apt install iftop

# Monitor tunnel interface traffic
sudo iftop -i any -f 'port 7000'

# Monitor all tunnel traffic
sudo iftop -i any -f 'port 7000 or port 8081'

# Bandwidth per connection
sudo nethogs
```

### DNS Query Monitoring
```bash
# Monitor DNS queries
sudo tcpdump -i any -n 'udp port 53'

# Count queries per second
sudo tcpdump -i any -n 'udp port 53' | pv -l -i 1 > /dev/null

# Log queries to file
sudo tcpdump -i any -n 'udp port 53' -w dns_queries.pcap

# Analyze captured queries
tcpdump -r dns_queries.pcap -n
```

### Load Balancing Verification
```bash
# View nftables rules
sudo nft list ruleset | grep -A 20 smuggler

# Connection tracking
sudo conntrack -L | grep DNAT

# Monitor load distribution
watch -n 2 'sudo netstat -tn | grep ":808[0-9]" | awk "{print \$4}" | sort | uniq -c'
```

### Health Check Status

If health checks are enabled:
```bash
# View health check logs
journalctl -u smuggler@tun0 | grep -i health

# Monitor health check results
journalctl -u smuggler@tun0 -f | grep -i "health\|check"
```

### Engine-Specific Tuning

#### slipstream
```yaml
server:
  max_connections: 1024        # Increase for high traffic
  idle_timeout_seconds: 10    # Adjust based on usage pattern

client:
  keep_alive_interval: 200    # Lower = more responsive, higher = less overhead
```

#### dnstt
```yaml
server:
  mtu: 1232                   # Lower if packet loss, higher for performance

client:
  mtu: 1232
```

### Disaster Recovery

If a tunnel fails completely:
```bash
# 1. Stop failed service
systemctl stop smuggler@tun0

# 2. Backup logs
journalctl -u smuggler@tun0 > /tmp/tun0_crash_logs.txt

# 3. Remove service
rm /etc/systemd/system/smuggler@tun0.service
systemctl daemon-reload

# 4. Redeploy
ansible-playbook -i inventory/hosts.yml smuggler.yml --limit=client1
```

## Security

### Access Control
```bash
# Restrict local proxy to localhost only
# In tunnels.yml:
client:
  bind_addr: 127.0.0.1  # Not 0.0.0.0
  bind_port: 7000

# Firewall rules (example)
sudo ufw allow from 192.168.1.0/24 to any port 7000
sudo ufw deny from any to any port 7000
```

### Monitoring for Anomalies
```bash
# Unusual connection spikes
watch -n 5 'sudo netstat -tn | grep ":7000" | wc -l'

# High bandwidth usage
sudo iftop -i any -f 'port 7000'

# Failed connection attempts
journalctl -u smuggler@tun0
```

## Maintenance Tasks

### Regular Tasks

**Daily:**
- Check service status: `systemctl status 'smuggler@*'`
- Review error logs: `journalctl -u 'smuggler@*' -p err --since today`

**Weekly:**
- Verify DNS records: `dig NS t.example.com`
- Check disk usage: `journalctl --disk-usage`
- Review connection stats

**Monthly:**
- Rotate logs: `journalctl --vacuum-time=30d`
- Update binaries (redeploy): `ansible-playbook -i inventory/hosts.yml smuggler.yml`
- Backup configuration

### Upgrading
```bash
# 1. Backup current config
tar -czf smuggler-backup-$(date +%Y%m%d).tar.gz inventory/

# 2. Pull latest code
git pull origin main

# 3. Test in dry-run mode
ansible-playbook -i inventory/hosts.yml smuggler.yml --check

# 4. Deploy updates
ansible-playbook -i inventory/hosts.yml smuggler.yml

# 5. Verify all services
ansible all -i inventory/hosts.yml -a "systemctl status 'smuggler@*'"
```

---

## Next Steps

- [Troubleshoot common issues](troubleshooting.md)
