# Troubleshooting

Common issues and their solutions.

## Service Issues

### Tunnel Service Won't Start

**Symptoms:**
```bash
systemctl status smuggler@tun0
● smuggler@tun0.service - Smuggler DNS Tunnel: tun0
   Active: failed (Result: exit-code)
```

**Diagnosis:**
```bash
# Check detailed logs
journalctl -u smuggler@tun0 -n 50 --no-pager

# Test binary manually
/usr/local/bin/slipstream-client --help

# Verify service file
cat /etc/systemd/system/smuggler@tun0.service
```

**Common Causes & Solutions:**

1. **Binary missing**
```bash
   # Check if binary exists
   ls -l /usr/local/bin/slipstream-client
   
   # Redeploy to download binaries
   ansible-playbook -i inventory/hosts.yml smuggler.yml
```

2. **Port already in use**
```bash
   # Find what's using the port
   sudo netstat -tlnp | grep :7000
   
   # Kill process or change bind_port in tunnels.yml
```

3. **Invalid configuration**
```bash
   # Check systemd service file syntax
   systemd-analyze verify /etc/systemd/system/smuggler@tun0.service
   
   # Reload systemd
   systemctl daemon-reload
```

### Tunnel Starts But Immediately Crashes

**Symptoms:**
Service shows `activating (auto-restart)` continuously.

**Diagnosis:**
```bash
# Watch real-time logs
journalctl -u smuggler@tun0 -f

# Look for crash pattern
journalctl -u smuggler@tun0 | tail -100
```

**Common Causes:**

1. **DNS resolver unreachable**
```bash
   # Test resolver
   dig @8.8.8.8 google.com
   
   # Try different resolver in tunnels.yml
```

2. **Server not reachable**
```bash
   # Test DNS delegation
   dig NS t.example.com
   dig @ns.example.com test.t.example.com
   
   # Verify server is running
   ssh server1 "systemctl status smuggler@tun0"
```

3. **Invalid domain configuration**
```bash
   # Verify NS record points to correct IP
   dig NS t.example.com +short
   dig A ns.example.com +short
```

---

## Connection Issues

### Can't Connect Through Tunnel

**Symptoms:**
```bash
curl --proxy socks5h://127.0.0.1:7000 https://google.com
curl: (7) Failed to connect to 127.0.0.1 port 7000: Connection refused
```

**Diagnosis:**
```bash
# Check if tunnel is running
systemctl status smuggler@tun0

# Check if port is listening
sudo netstat -tlnp | grep 7000

# View recent logs
journalctl -u smuggler@tun0 -n 50
```

**Solutions:**

1. **Service not running**
```bash
   systemctl start smuggler@tun0
   systemctl enable smuggler@tun0  # Start on boot
```

2. **Wrong bind address**
```yaml
   # In tunnels.yml, ensure:
   client:
     bind_addr: 0.0.0.0  # Not 127.0.0.1 if connecting from other hosts
```

3. **Firewall blocking**
```bash
   # Allow port
   sudo ufw allow 7000/tcp
   
   # Or disable firewall temporarily to test
   sudo ufw disable
```

### Tunnel Connects But No Data Flows

**Symptoms:**
Connection established but requests timeout.

**Diagnosis:**
```bash
# Monitor tunnel traffic
sudo tcpdump -i any -n port 7000

# Check DNS queries reaching server
ssh server1 "sudo tcpdump -i any -n udp port 53"

# Test with verbose curl
curl -v --proxy socks5h://127.0.0.1:7000 https://google.com
```

**Solutions:**

1. **DNS queries not reaching server**
```bash
   # Verify NS delegation
   dig NS t.example.com
   
   # Test direct query to server
   dig @server-ip random.t.example.com
```

2. **Server firewall blocking UDP/53**
```bash
   # On server
   sudo ufw allow 53/udp
   sudo iptables -A INPUT -p udp --dport 53 -j ACCEPT
```

3. **Backend service not running on server**
```bash
   # Verify target service
   ssh server1 "netstat -tlnp | grep :7000"
   
   # Start proxy service on server
   ssh server1 "systemctl start your-proxy-service"
```

---

## DNS Issues

### SERVFAIL Responses

**Symptoms:**
```bash
dig @8.8.8.8 test.t.example.com
;; Got SERVFAIL reply from 8.8.8.8
```

**Diagnosis:**
```bash
# Check NS record
dig NS t.example.com

# Query nameserver directly
dig @ns.example.com test.t.example.com

# Check server logs
ssh server1 "journalctl -u smuggler@tun0 -n 50"
```

**Solutions:**

1. **NS record incorrect**
```bash
   # Verify NS points to right server
   dig NS t.example.com +short
   # Should return: ns.example.com
   
   dig A ns.example.com +short
   # Should return: your-server-ip
```

2. **Server not responding to DNS**
```bash
   # Check if server is listening on port 53
   ssh server1 "netstat -ulnp | grep :53"
   
   # Restart tunnel
   ssh server1 "systemctl restart smuggler@tun0"
```

3. **Firewall blocking UDP/53**
```bash
   ssh server1 "sudo ufw allow 53/udp"
```

### DNS Propagation Delays

**Symptoms:**
NS record not resolving after adding.

**Solutions:**

1. **Wait for propagation** (5-15 minutes typically)

2. **Check specific DNS servers**
```bash
   dig NS t.example.com @8.8.8.8
   dig NS t.example.com @1.1.1.1
```

3. **Flush local DNS cache**
```bash
   # Linux
   sudo systemd-resolve --flush-caches
   
   # macOS
   sudo dscacheutil -flushcache
```

4. **Lower TTL temporarily**
   Set DNS TTL to 60 seconds during testing.

---

## Load Balancing Issues

### Traffic Not Distributing

**Symptoms:**
All traffic going to single tunnel.

**Diagnosis:**
```bash
# Monitor connections per tunnel
watch -n 1 'sudo netstat -tn | grep ":700[0-9]" | awk "{print \$4}" | sort | uniq -c'

# Check nftables rules
sudo nft list ruleset
```

**Solutions:**

1. **Load balancing not enabled**
```yaml
   # In lb.yml
   load_balancing: true
   
   lb:
     enabled: true
     type: "roundrobin"
     ports: ["80", "443"]
```

2. **nftables rules missing**
```bash
   # Redeploy load balancing
   ansible-playbook -i inventory/hosts.yml playbooks/client.yml --tags lb
   
   # Verify rules
   sudo nft list table ip smuggler_lb
```

3. **Connection affinity (hash mode)**
   Hash mode maintains same tunnel for same source IP.
```yaml
   # Try roundrobin instead
   lb:
     enabled: true
     type: "roundrobin"
```

### DNS Resolver Load Balancing Not Working

**Symptoms:**
All queries going to single resolver.

**Diagnosis:**
```bash
# Monitor DNS traffic
sudo tcpdump -i any -n 'udp port 53' -v

# Check resolver in tunnel process
ps aux | grep slipstream-client
```

**Solutions:**

1. **DNS LB not enabled**
```yaml
   # In lb.yml
   load_balancing: true

   dns_lb:
     enabled: true
     type: "roundrobin"
     resolvers: ["1.1.1.1", "8.8.8.8"]
```

2. **Restart required**
```bash
   # Changes need service restart
   systemctl restart 'smuggler@*'
```

3. **Per-tunnel resolver overriding**
```yaml
   # Remove per-tunnel dns_resolver when using DNS LB
   # tunnels.yml:
   client:
     # dns_resolver: "8.8.8.8:53"  # Remove this line
```

---

## Performance Issues

### Slow Connection Speed

**Diagnosis:**
```bash
# Test throughput
curl --proxy socks5h://127.0.0.1:7000 -o /dev/null https://speed.cloudflare.com/__down?bytes=100000000

# Monitor bandwidth
sudo iftop -i any -f 'port 7000'
```

**Solutions:**

1. **Increase connection pool (slipstream)**
```yaml
   server:
     max_connections: 1024  # Up from default 256
```

2. **Use slipstream instead of dnstt**
```yaml
   engine: slipstream  # Faster than dnstt
```

### High Latency

**Diagnosis:**
```bash
# Measure latency through tunnel
curl --proxy socks5h://127.0.0.1:7000 -o /dev/null -w "%{time_total}\n" https://google.com

# Compare with direct connection
curl -o /dev/null -w "%{time_total}\n" https://google.com
```

**Solutions:**

1. **Use closer DNS resolver**
```yaml
   dns_resolver: "1.1.1.1:53"  # Usually fastest
```

2. **Reduce keep-alive interval (slipstream)**
```yaml
   client:
     keep_alive_interval: 100  # Lower = more responsive
```

3. **Check network path**
```bash
   # Trace route to server
   traceroute server-ip
   
   # Check for packet loss
   ping -c 100 server-ip
```

---

## Deployment Issues

### Ansible Can't Connect

**Error:**
```
UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh"}
```

**Solutions:**

1. **Verify SSH connectivity**
```bash
   ssh root@server-ip
```

2. **Check SSH key**
```bash
   ssh-add -l
   ssh-add ~/.ssh/id_rsa
```

3. **Test with password**
```bash
   ansible all -i inventory/hosts.yml -m ping --ask-pass
```

4. **Verify hosts.yml**
```yaml
   all:
     vars:
       ansible_user: root
       ansible_port: 22
     hosts:
       server1:
         ansible_host: 203.0.113.10  # Correct IP?
```

### Binary Download Failed

**Error:**
```
failed: [server1] => {"msg": "Failed to download binary from GitHub"}
```

**Solutions:**

1. **Check internet connectivity**
```bash
   ssh server1 "curl -I https://github.com"
```

2. **Check /tmp permissions**
```bash
   ssh server1 "ls -ld /tmp"
```

3. **Manual download**
```bash
   # Download manually and place in /usr/local/bin/
   wget https://github.com/.../slipstream-server
   chmod +x slipstream-server
   scp slipstream-server root@server1:/usr/local/bin/
```

---

## Health Check Issues

### Health Checks Always Failing

**Diagnosis:**
```bash
# Check health check logs
journalctl -u smuggler@tun0 | grep -i health

# Test proxy manually
curl --proxy http://127.0.0.1:7000 http://www.google.com/gen_204
```

**Solutions:**

1. **Backend proxy not running**
```bash
   # Verify target service
   netstat -tlnp | grep :7000
   
   # Start backend service
   systemctl start your-proxy
```

2. **Wrong proxy type**
```yaml
   health_check:
     proxy_type: http  # Should match backend (http or socks5)
```

3. **Timeout too short**
```yaml
   health_check:
     timeout: 10  # Increase from 5
```

4. **Test URL unreachable**
```yaml
   health_check:
     test_url: "http://www.google.com/gen_204"  # Try different URL
```

---

## Debug Mode

### Packet Capture
```bash
# Capture all tunnel traffic
sudo tcpdump -i any -n port 7000 -w tunnel_traffic.pcap

# Capture DNS queries
sudo tcpdump -i any -n 'udp port 53' -w dns_traffic.pcap

# Analyze later
tcpdump -r tunnel_traffic.pcap -n
```

---

## Getting Help

If issues persist:

1. **Collect diagnostics**
```bash
   # Service status
   systemctl status 'smuggler@*' > diagnostics.txt
   
   # Logs
   journalctl -u 'smuggler@*' -n 200 >> diagnostics.txt
   
   # Configuration
   cat inventory/group_vars/all/tunnels.yml >> diagnostics.txt
   
   # Network info
   ip addr >> diagnostics.txt
   netstat -tlnp >> diagnostics.txt
```

2. **Check documentation**
   - [Configuration Guide](configuration.md)
   - [DNS Setup](dns-setup.md)
   - [Operations](operations.md)

3. **Open GitHub issue**
   Include:
   - Smuggler version (`git rev-parse HEAD`)
   - OS version (`cat /etc/os-release`)
   - Error logs
   - Configuration (redact sensitive info)

---

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `bind: address already in use` | Port conflict | Change `bind_port` or kill process |
| `connection refused` | Service not running | `systemctl start smuggler@tun0` |
| `no such file or directory` | Binary missing | Redeploy to download binaries |
| `SERVFAIL` | DNS misconfigured | Check NS records |
| `timeout` | Network/firewall issue | Check connectivity, firewall rules |
| `permission denied` | Insufficient privileges | Run with sudo or fix permissions |

---

## Preventive Measures

1. **Health monitoring**
   Enable health checks in production:
```yaml
   client:
     health_check:
       enabled: true
       interval: "3s"
       # ...
```

2. **Redundancy**
   Deploy multiple tunnels for failover:
```yaml
   tunnels:
     - name: primary
       # ...
     - name: backup
       # ...
```
