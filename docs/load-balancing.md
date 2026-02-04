# Load Balancing

Smuggler provides kernel-level load balancing using Linux nftables for high-performance traffic distribution.

## Types of Load Balancing

### 1. Traffic Load Balancing
Distribute client traffic across multiple tunnel servers.

### 2. DNS Resolver Load Balancing
Distribute DNS queries across multiple resolvers.

---

## Traffic Load Balancing

**Location**: `inventory/group_vars/client_nodes/lb.yml`

### Configuration
```yaml
---
## Master switch: enables/disables ALL load balancing features
load_balancing: true

# Traffic load balancing - distributes client traffic across multiple tunnel servers
lb:
  enabled: true  # Enable traffic LB (requires load_balancing: true)
  type: "hash" # Options: hash, random, roundrobin
  ports:
    - "80"
    - "443"
    - "8080"
    - "8443"
    - "2052-2096"
    - "9200-9400"
```

### Load Balancing Algorithms

| Type | Behavior | Use Case |
|------|----------|----------|
| `hash` | Consistent hashing by source IP/port | Sticky sessions, maintain connection affinity |
| `random` | Random distribution | Simple load spreading |
| `roundrobin` | Sequential distribution | Even distribution across tunnels |

### How It Works

1. Client applications connect to local proxy (e.g., `127.0.0.1:7000`)
2. nftables intercepts outbound traffic on configured ports
3. Traffic is distributed across active tunnel endpoints
4. Kernel maintains connection state for return traffic

### Requirements

**Critical**: All server-side backend services must be identical.

✅ **Valid configurations:**
- Same HTTP proxy on all servers
- Same SOCKS5 proxy on all servers
- Same SSH tunnel on all servers

❌ **Invalid configurations:**
- Shadowsocks on server1, SSH SOCKS on server2
- Different proxy types across servers
- Inconsistent backend configurations

### Example: Load Balance Across 2 Tunnels

**tunnels.yml:**
```yaml
tunnels:
  - name: tun0
    client_node: lb0
    server_node: server1
    engine: slipstream
    domain: t1.example.com
    client:
      bind_port: 8080
    server:
      target_port: 3128  # proxy

  - name: tun1
    client_node: lb0
    server_node: server2
    engine: slipstream
    domain: t2.example.com
    client:
      bind_port: 8081
    server:
      target_port: 3128  # Must be same proxy
```

**lb.yml:**
```yaml
load_balancing: true

lb:
  enabled: true
  type: "roundrobin"
  ports:
    - "80"
    - "443"
```

**Result**: traffic automatically distributed between `tun0` and `tun1`.

---

## DNS Resolver Load Balancing

Distribute DNS queries across multiple resolvers at the kernel level.

**Location**: `inventory/group_vars/client_nodes/lb.yml`

### Configuration
```yaml
---
# DNS resolver load balancing - distributes DNS queries across multiple resolvers
dns_lb:
  enabled: true  # Enable DNS LB (requires load_balancing: true)
  type: "roundrobin" # Options: hash, random, roundrobin
  resolvers:
    - "1.1.1.1"
    - "8.8.8.8"
    - "9.9.9.9"
```

### How It Works

1. Per-tunnel `dns_resolver` is ignored when DNS LB is enabled
2. All tunnels use resolvers from `dns_lb.resolvers` list
3. Kernel distributes queries based on `dns_lb.type`
4. Connection tracking ensures consistent resolver per source port

### When to Use

✅ **Good use cases:**
- Redundancy: if one resolver fails, others continue
- Avoid rate limiting from single resolver
- Geographic distribution for lower latency
- Bypass resolver-specific filtering

❌ **Not recommended:**
- Single tunnel with low traffic
- When resolver consistency is required

### Example Configuration

**tunnels.yml:**
```yaml
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t1.example.com
    # No dns_resolver specified - will use DNS LB

  - name: tun1
    client_node: client1
    server_node: server2
    engine: dnstt
    domain: t2.example.com
    # No dns_resolver specified - will use DNS LB
```

**lb.yml:**
```yaml
dns_lb:
  enabled: true
  type: "hash"
  resolvers:
    - "1.1.1.1"
    - "8.8.8.8"
    - "9.9.9.9"
```

**Result**: Both tunnels distribute queries across Cloudflare, Google, and Quad9.

### Important Notes

⚠️ **Resolver changes require restart:**
- nftables conntrack maintains resolver mapping per source port
- Changing resolvers won't affect existing connections
- Restart tunnel services to apply new resolvers:
```bash
  systemctl restart 'smuggler@*'
```

⚠️ **Default resolver:**
- If DNS LB is disabled and no per-tunnel `dns_resolver` is set, default is `8.8.8.8:53`

---

## Combining Both Load Balancing Types

You can use both traffic and DNS resolver load balancing simultaneously:
```yaml
---
load_balancing: true

# Traffic load balancing
lb:
  enabled: true
  type: "roundrobin"
  ports:
    - "80"
    - "443"
    - "8080"

# DNS resolver load balancing
dns_lb:
  enabled: true
  type: "hash"
  resolvers:
    - "1.1.1.1"
    - "8.8.8.8"
    - "9.9.9.9"
```

**Result:**
- Client traffic on ports 80/443/8080 distributed across tunnels
- DNS queries distributed across 3 resolvers

---

## Verification

### Check Traffic Load Balancing Rules
```bash
# View nftables rules
sudo nft list ruleset

# Check active connections
sudo conntrack -L | grep DNAT
```

### Check DNS Resolver Load Balancing
```bash
# Monitor DNS queries
sudo tcpdump -i any -n 'udp port 53'

# Generate test traffic
for i in {1..10}; do
  dig @localhost test$i.t.example.com
done

# Should see queries distributed across resolvers
```

### Monitor Tunnel Traffic
```bash
# Real-time traffic per tunnel
watch -n 1 'sudo iftop -i tun+'

# Connection count per tunnel
watch -n 1 'sudo netstat -tn | grep :7000 | wc -l'
```

---

## Troubleshooting

### Traffic Not Load Balancing

**Check:**
```bash
# Verify nftables rules exist
sudo nft list table ip smuggler_lb

# Check if tunnels are running
systemctl status 'smuggler@*'
```

**Solutions:**
- Ensure `lb.enabled: true` in `lb.yml`
- Verify all tunnels are healthy
- Restart load balancing service: `systemctl restart lb-smuggler.service`

### DNS Queries Using Wrong Resolver

**Check:**
```bash
# Monitor DNS traffic
sudo tcpdump -i any -n 'udp port 53' -v

# Check resolver in tunnel logs
journalctl -u smuggler@tun0 | grep resolver
```

**Solutions:**
- Restart tunnels: `systemctl restart 'smuggler@*'`
- Verify `dns_lb.enabled: true` in `lb.yml`
- Check resolver list in `dns_lb.resolvers`

---

## Best Practices

1. **Test resolvers before deployment**
```bash
   dig @1.1.1.1 test.t.example.com
   dig @8.8.8.8 test.t.example.com
```

2. **Use `hash` for DNS LB**
   - Provides better cache hit rates
   - More predictable behavior

3. **Use `roundrobin` for traffic LB**
   - Even distribution
   - Simple and reliable

4. **Monitor connection distribution**
```bash
   watch -n 5 'sudo netstat -tn | grep ":808[0-9]" | awk "{print \$4}" | sort | uniq -c'
```

5. **Plan for resolver failures**
   - Use at least 3 resolvers
   - Test failover behavior

---

## Next Steps

- [Deploy load-balanced infrastructure](deployment.md)
- [Monitor tunnel operations](operations.md)
