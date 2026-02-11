# Load Balancing

Smuggler has two independent load balancing layers, each serving a different purpose:

- **Client-side traffic LB** — distributes TCP traffic across multiple tunnel instances using nftables (kernel-level)
- **Client-side DNS LB** — distributes DNS queries across multiple resolvers using DNSdist
- **Server-side DNS LB** — distributes incoming DNS queries across multiple tunnel server instances using DNSdist

These are all **disabled by default**. You opt in to each one explicitly.

---

## Client-Side Traffic Load Balancing

When you have multiple tunnel instances running on a client node, the traffic LB distributes incoming TCP connections across them using nftables DNAT rules.

### How it works

nftables intercepts traffic on configured ports and forwards each connection to one of the tunnel instances based on your chosen policy. When a tunnel becomes unhealthy, the health checker replaces it with a backup address — it does **not** modify nftables rules dynamically. When the tunnel recovers, it takes back its slot.

### Enabling

In `inventory/group_vars/client_nodes/lb.yml`:

```yaml
lb: true
lb_policy: "hash"        # hash | roundrobin | random
lb_ports:
  - "8080"
  - "10000-10200"
```

Then in each tunnel definition, set `client.lb.enabled: true` and define a backup:

```yaml
tunnels:
  - name: tun0
    client_node: lb0
    server_node: node0
    engine: slipstream
    domain: t.example.com
    client:
      lb:
        enabled: true
        backup_addr: 127.0.0.1
        backup_port: 5202
      bind_addr: 127.0.0.1
      bind_port: 5200

  - name: tun1
    client_node: lb0
    server_node: node1
    engine: slipstream
    domain: t2.example.com
    client:
      lb:
        enabled: true
        backup_addr: 127.0.0.1
        backup_port: 5203
      bind_addr: 127.0.0.1
      bind_port: 5201
```

### Rules when using traffic LB

- `client.bind_addr` **must** be `127.0.0.1` for all participating tunnels
- Each tunnel **must** have a unique `client.bind_port`
- Each tunnel **must** define `client.lb.backup_addr` and `client.lb.backup_port`
- All server-side proxy backends **must be consistent** — you cannot mix SSH proxy on one server and Xray on another when load balancing across them

### LB policies

| Policy | Behavior |
|--------|----------|
| `hash` | Consistent hashing on source IP + port. Same client always hits the same tunnel. |
| `roundrobin` | Increments sequentially across tunnels. |
| `random` | Random selection per connection. |

### Default values

| Key | Default |
|-----|---------|
| `lb` | `false` |
| `lb_policy` | `hash` |
| `lb_ports` | `["8080", "10000-10200"]` |
| `client.lb.enabled` | `false` |
| `client.lb.backup_addr` | `127.0.0.1` |
| `client.lb.backup_port` | *(required when lb enabled)* |

---

## Client-Side DNS Query Load Balancing

Distributes DNS queries across multiple upstream resolvers. Useful when a single resolver is unreliable or rate-limited.

Uses DNSdist running locally on the client node.

### Enabling

In `inventory/group_vars/client_nodes/lb.yml`:

```yaml
dnsdist: true
dnsdist_bind_addr: "127.0.0.1"
dnsdist_bind_port: 5300

dnsdist_upstream_servers:
  - address: "1.1.1.1:53"
  - address: "8.8.8.8:53"
  - address: "9.9.9.9:53"
```

Then in your tunnel definitions, point `dns_resolver` at DNSdist:

```yaml
tunnels:
  - name: tun0
    client_node: lb0
    server_node: node0
    engine: slipstream
    domain: t.example.com
    client:
      dns_resolver: "127.0.0.1:5300"
```

### Using multiple resolvers per tunnel (slipstream only)

Slipstream supports a list of resolvers natively. dnstt does not — it accepts only one resolver string.

```yaml
# slipstream only
client:
  dns_resolver:
    - "1.1.1.1:53"
    - "8.8.8.8:53"
    - "9.9.9.9:53"
```

For dnstt with multiple resolvers, use DNSdist and point `dns_resolver` at it.

### DNSdist server options

Each entry in `dnsdist_upstream_servers` supports these fields (all optional, shown with defaults):

```yaml
dnsdist_upstream_servers:
  - address: "8.8.8.8:53"
    check_interval: 2          # seconds between health checks
    check_timeout: 1000        # ms before check is considered failed
    check_type: "TXT"          # record type used for health checks
    max_check_failures: 1      # failures before marking down
    must_resolve: true         # must return a valid answer
    use_client_subnet: false   # pass client IP in EDNS
    tcp_only: false            # force TCP for all queries
    check_tcp: false           # health check over TCP
    dscp: 0                    # DSCP marking
    reconnect_on_up: false     # reconnect TCP on server recovery
    rise: 1                    # successful checks to mark server up
```

### LB policies for DNS

| Policy | Behavior |
|--------|----------|
| `leastOutstanding` | Routes to server with fewest in-flight queries (default) |
| `roundrobin` | Rotates through servers in order |
| `firstAvailable` | Always uses first responsive server |
| `wrandom` | Weighted random based on `weight` |
| `chashed` | Consistent hashing |

### Default values (client DNSdist)

| Key | Default |
|-----|---------|
| `dnsdist` | `false` |
| `dnsdist_bind_addr` | `127.0.0.1` |
| `dnsdist_bind_port` | `5300` |
| `dnsdist_server_policy` | `leastOutstanding` |
| `dnsdist_acl` | `["127.0.0.0/8"]` |
| `dnsdist_udp_timeout` | `2` |
| `dnsdist_max_udp_outstanding` | `65535` |
| `dnsdist_tcp_recv_timeout` | `2` |
| `dnsdist_tcp_send_timeout` | `2` |
| `dnsdist_metrics` | `false` |
| `dnsdist_metrics_bind_addr` | `127.0.0.1` |
| `dnsdist_metrics_bind_port` | `8083` |
| `dnsdist_metrics_require_auth` | `false` |
| `dnsdist_metrics_password` | `admin` |

---

## Server-Side DNS Load Balancing

When you run multiple tunnel instances on the same server (or across servers per domain), DNSdist on port 53 distributes queries to each instance.

Each tunnel instance must **not** bind to port 53 directly — DNSdist owns port 53.

### Enabling

In `inventory/group_vars/server_nodes/lb.yml`:

```yaml
dnsdist: true
dnsdist_bind_addr: "0.0.0.0"
dnsdist_bind_port: 53
dnsdist_server_policy: "leastOutstanding"
```

With server-side LB enabled, tunnel server instances must bind to `127.0.0.1` on distinct ports:

```yaml
tunnels:
  - name: tun0
    client_node: lb0
    server_node: node0
    engine: slipstream
    domain: t.example.com
    server:
      bind_addr: "127.0.0.1"
      bind_port: 5300

  - name: tun1
    client_node: lb0
    server_node: node0
    engine: dnstt
    domain: d.example.com
    server:
      bind_addr: "127.0.0.1"
      bind_port: 5301
```

DNSdist automatically routes queries for each domain to the correct pool of tunnel instances. Queries that don't match any tunnel domain are dropped by default.

### Domain-based routing

DNSdist groups tunnel instances by domain. All instances sharing a domain go into the same pool and queries for that domain are load balanced across them. If you have multiple tunnels on the same domain, they all receive traffic.

### Default action for non-matching queries

| Value | Behavior |
|-------|----------|
| `drop` | Silently drop (default) |
| `refuse` | Return REFUSED |
| `forward` | Forward to upstream servers |

### Upstream servers (for forwarding)

If `dnsdist_default_action: "forward"`, you should define upstream servers for non-tunnel queries:

```yaml
dnsdist_upstream_servers:
  - address: "8.8.8.8:53"
  - address: "8.8.4.4:53"
```

### Default values (server DNSdist)

| Key | Default |
|-----|---------|
| `dnsdist` | `false` |
| `dnsdist_bind_addr` | `0.0.0.0` |
| `dnsdist_bind_port` | `53` |
| `dnsdist_server_policy` | `leastOutstanding` |
| `dnsdist_acl` | `["0.0.0.0/0", "::/0"]` |
| `dnsdist_default_action` | `drop` |
| `dnsdist_udp_timeout` | `2` |
| `dnsdist_max_udp_outstanding` | `65535` |
| `dnsdist_tcp_recv_timeout` | `2` |
| `dnsdist_tcp_send_timeout` | `2` |
| `dnsdist_metrics` | `false` |
| `dnsdist_metrics_bind_addr` | `127.0.0.1` |
| `dnsdist_metrics_bind_port` | `8083` |
| `dnsdist_metrics_require_auth` | `false` |
| `dnsdist_metrics_password` | `admin` |

### Important note on dnsdist scope

If you set `dnsdist: true` in `inventory/group_vars/all/`, it enables DNSdist on **both** client and server nodes. This will likely cause port conflicts. Set it per group:

- `inventory/group_vars/client_nodes/lb.yml` for client DNS LB
- `inventory/group_vars/server_nodes/lb.yml` for server DNS LB

---

## Prometheus Metrics

Both client and server DNSdist instances support a metrics endpoint. Disabled by default.

```yaml
dnsdist_metrics: true
dnsdist_metrics_bind_addr: "127.0.0.1"
dnsdist_metrics_bind_port: 8083
dnsdist_metrics_require_auth: false
dnsdist_metrics_password: "admin"
# dnsdist_metrics_api_key: ""
# dnsdist_metrics_acl:
#   - "0.0.0.0/0"
```

---

## Production Example: N:N With Full LB

Multiple clients, multiple servers, traffic LB on clients, DNS LB on servers.

**`inventory/group_vars/server_nodes/lb.yml`:**
```yaml
dnsdist: true
dnsdist_server_policy: "leastOutstanding"
dnsdist_default_action: "drop"
```

**`inventory/group_vars/client_nodes/lb.yml`:**
```yaml
lb: true
lb_policy: "hash"
lb_ports:
  - "8080"
  - "443"

dnsdist: true
dnsdist_bind_port: 5300
dnsdist_upstream_servers:
  - address: "1.1.1.1:53"
  - address: "8.8.8.8:53"
  - address: "9.9.9.9:53"
```

**`inventory/group_vars/all/tunnels.yml`:**
```yaml
tunnels:
  - name: tun0
    client_node: lb0
    server_node: node0
    engine: slipstream
    domain: t.example.com
    client:
      lb:
        enabled: true
        backup_addr: 127.0.0.1
        backup_port: 5202
      bind_addr: 127.0.0.1
      bind_port: 5200
      dns_resolver: "127.0.0.1:5300"
      health_check:
        enabled: true
        proxy_type: http
        proxy_addr: 127.0.0.1
        proxy_port: 5200
        test_url: "http://www.google.com/gen_204"
    server:
      bind_addr: "127.0.0.1"
      bind_port: 5300

  - name: tun1
    client_node: lb0
    server_node: node1
    engine: slipstream
    domain: t.example.com
    client:
      lb:
        enabled: true
        backup_addr: 127.0.0.1
        backup_port: 5203
      bind_addr: 127.0.0.1
      bind_port: 5201
      dns_resolver: "127.0.0.1:5300"
      health_check:
        enabled: true
        proxy_type: http
        proxy_addr: 127.0.0.1
        proxy_port: 5201
        test_url: "http://www.google.com/gen_204"
    server:
      bind_addr: "127.0.0.1"
      bind_port: 5301
```
