# DNS Setup

DNS tunnels require specific DNS records to route queries to your server.

## Prerequisites

- A domain you own (e.g., `example.com`)
- Access to DNS management (registrar or DNS provider)
- Static IP address for your tunnel server

## Required DNS Records

For each tunnel, you need two records:

| Record Type | Purpose |
|-------------|---------|
| **A** | Points nameserver subdomain to your server IP |
| **NS** | Delegates tunnel subdomain to your nameserver |

## Single Tunnel Example

**Configuration:**
```yaml
tunnels:
  - name: tun0
    server_node: server1  # IP: 203.0.113.10
    domain: t.example.com
```

**DNS Records:**

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `ns.example.com` | `203.0.113.10` | 300 |
| NS | `t.example.com` | `ns.example.com` | 300 |

**Explanation:**
1. `ns.example.com` → Points to server IP `203.0.113.10`
2. `t.example.com` → Delegates DNS queries to `ns.example.com`

## Multiple Tunnels Example

**Configuration:**
```yaml
tunnels:
  - name: tun0
    server_node: server1  # IP: 203.0.113.10
    domain: fast.example.com
  
  - name: tun1
    server_node: server2  # IP: 203.0.113.11
    domain: backup.example.com
```

**DNS Records:**

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `ns1.example.com` | `203.0.113.10` | 300 |
| A | `ns2.example.com` | `203.0.113.11` | 300 |
| NS | `fast.example.com` | `ns1.example.com` | 300 |
| NS | `backup.example.com` | `ns2.example.com` | 300 |

## Step-by-Step Setup

### 1. Find Your Server IP
```bash
# On your server
curl ifconfig.me
# or
ip addr show
```

### 2. Create A Record (Nameserver)

In your DNS provider's control panel:

- **Record Type**: A
- **Name**: `ns` (or `ns1`, `tns`, etc.)
- **Value**: Your server IP (e.g., `203.0.113.10`)
- **TTL**: `300` (5 minutes)

### 3. Create NS Record (Delegation)

- **Record Type**: NS
- **Name**: Your tunnel subdomain (e.g., `t`)
- **Value**: Your nameserver (e.g., `ns.example.com`)
- **TTL**: `300`

### 4. Verify DNS Propagation
```bash
# Check NS record
dig NS t.example.com

# Expected output:
# t.example.com. 300 IN NS ns.example.com.

# Check if server responds
dig @ns.example.com test.t.example.com

# Should see your server IP in AUTHORITY section
```

## Testing DNS Resolution

### From Client Side
```bash
# Test DNS query through tunnel domain
dig @8.8.8.8 random-query.t.example.com

# Should return NXDOMAIN or NOERROR (not SERVFAIL)
```

### From Server Side

Monitor incoming DNS traffic:
```bash
# On server
sudo tcpdump -i any -n udp port 53

# Generate test query from another machine
dig @your-server-ip test.t.example.com
```

## Common DNS Providers

### Cloudflare

1. Log into Cloudflare dashboard
2. Select your domain
3. Go to **DNS** → **Records**
4. Click **Add record**
5. Add A and NS records as shown above

### Namecheap

1. Log into Namecheap account
2. **Domain List** → Manage
3. **Advanced DNS** tab
4. Add records using **Add New Record** button

### AWS Route 53
```bash
# Create hosted zone (if needed)
aws route53 create-hosted-zone --name example.com

# Create A record
aws route53 change-resource-record-sets --hosted-zone-id ZONE_ID --change-batch '{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "ns.example.com",
      "Type": "A",
      "TTL": 300,
      "ResourceRecords": [{"Value": "203.0.113.10"}]
    }
  }]
}'

# Create NS record
aws route53 change-resource-record-sets --hosted-zone-id ZONE_ID --change-batch '{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "t.example.com",
      "Type": "NS",
      "TTL": 300,
      "ResourceRecords": [{"Value": "ns.example.com"}]
    }
  }]
}'
```

## Troubleshooting

### NS Record Not Propagating

**Check:**
```bash
dig NS t.example.com @8.8.8.8
dig NS t.example.com @1.1.1.1
```

**Solutions:**
- Wait 5-15 minutes for DNS propagation
- Clear DNS cache: `sudo systemd-resolve --flush-caches`
- Lower TTL to 60 seconds temporarily

### Server Not Responding to DNS

**Check server firewall:**
```bash
# Allow UDP port 53
sudo ufw allow 53/udp
# or
sudo iptables -A INPUT -p udp --dport 53 -j ACCEPT
```

**Check if server is listening:**
```bash
sudo netstat -ulnp | grep :53
```

### SERVFAIL Responses

This usually means NS delegation is incorrect.

**Verify:**
```bash
# Should return your NS record
dig NS t.example.com

# Should return same result
dig NS t.example.com @ns.example.com
```

## DNS Resolver Compatibility

Some DNS resolvers block tunneling. Test before deployment:

**Test a resolver:**
```bash
dig @resolver-ip random-subdomain.t.example.com
# Should return NXDOMAIN, not SERVFAIL
```

---

## Next Steps

- [Configure load balancing](load-balancing.md)
- [Deploy tunnels](deployment.md)
