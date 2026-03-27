# Load Balancing

Smuggler has three independent balancing layers:

- client traffic balancing through nftables
- client DNS resolver balancing through DNSdist
- server-side DNS pooling through DNSdist

They are all disabled by default.

## Client Traffic Balancing

This balances TCP connections across multiple tunnel instances on the same client node. It is a good fit when one client node runs several tunnels and you want kernel-level distribution.

### Example

```yaml
load_balancing: true
load_balancing_policy: roundrobin
load_balancing_ports:
  - "8080"
  - "10000-10200"

tunnels:
  - name: t00
    client_node: lb0
    server_node: node0
    engine: vaydns
    domain: t0.example.com
    client:
      lb:
        enabled: true
        backup_addr: 127.0.0.1
        backup_port: 2051
      bind_addr: 127.0.0.1
      bind_port: 2050
```

### Rules

| Rule | Why |
|------|-----|
| `client.lb.enabled` must be `true` | The health checker only swaps backends when LB is active |
| `client.bind_addr` should be `127.0.0.1` | nftables forwards to local tunnel listeners |
| Each tunnel needs a unique `client.bind_port` | The NAT map uses the port to pick the backend |
| `client.lb.backup_addr` and `backup_port` must exist | Health failover switches to this backend |

### Defaults

| Key | Default |
|-----|---------|
| `load_balancing` | `false` |
| `load_balancing_policy` | `hash` |
| `load_balancing_ports` | `["8080", "10000-10200"]` |
| `client.lb.enabled` | `false` |
| `client.lb.backup_addr` | `127.0.0.1` |
| `client.lb.backup_port` | `client.bind_port` |

## Client DNSdist

Use client-side DNSdist when you want a local resolver fanout point. Point `client.dns_resolver` at DNSdist and Smuggler will send tunnel DNS traffic through it.

### Example

```yaml
dnsdist: true

tunnels:
  - name: tun0
    client_node: lb0
    server_node: node0
    engine: slipstream
    domain: t.example.com
    client:
      dns_resolver: "127.0.0.1:5300"
```

Slipstream also accepts a list of resolvers directly:

```yaml
client:
  dns_resolver:
    - "1.1.1.1:53"
    - "8.8.8.8:53"
```

### Defaults

| Key | Default |
|-----|---------|
| `dnsdist` | `false` |
| `dnsdist_bind_addr` | `127.0.0.1` |
| `dnsdist_bind_port` | `5300` |
| `dnsdist_server_policy` | `leastOutstanding` |
| `dnsdist_acl` | `["127.0.0.0/8"]` |
| `dnsdist_upstream_servers` | `8.8.8.8:53`, `8.8.4.4:53` |
| `dnsdist_udp_timeout` | `2` |
| `dnsdist_max_udp_outstanding` | `65535` |
| `dnsdist_tcp_recv_timeout` | `2` |
| `dnsdist_tcp_send_timeout` | `2` |
| `dnsdist_metrics` | `false` |
| `dnsdist_metrics_bind_addr` | `127.0.0.1` |
| `dnsdist_metrics_bind_port` | `8083` |
| `dnsdist_metrics_require_auth` | `false` |
| `dnsdist_metrics_password` | `admin` |

## Server DNSdist

Server-side DNSdist is what lets multiple tunnel instances share the same domain cleanly. DNSdist owns port 53 and forwards domain-matched queries to the tunnel backends.

### Example

```yaml
dnsdist: true
dnsdist_server_policy: firstAvailable
xray: true

tunnels:
  - name: t00
    server_node: node0
    client_node: lb0
    engine: vaydns
    domain: t0.example.com
    server:
      bind_addr: 127.0.0.1
      bind_port: 8200
      target_addr: 127.0.0.1
      target_port: 1081
```

### Behavior

| Behavior | Meaning |
|----------|---------|
| Same domain, multiple tunnels | DNSdist puts them in the same pool |
| Different domains | Each domain gets its own pool |
| `dnsdist_default_action: drop` | Non-matching queries are dropped |
| `dnsdist_default_action: refuse` | Non-matching queries get `REFUSED` |
| `dnsdist_default_action: forward` | Non-matching queries go to the `default` pool |

### Defaults

| Key | Default |
|-----|---------|
| `dnsdist` | `false` |
| `dnsdist_bind_addr` | `0.0.0.0` |
| `dnsdist_bind_port` | `53` |
| `dnsdist_server_policy` | `firstAvailable` |
| `dnsdist_default_action` | `drop` |
| `dnsdist_acl` | `["0.0.0.0/0", "::/0"]` |
| `dnsdist_upstream_servers` | `8.8.8.8:53`, `8.8.4.4:53` |
| `dnsdist_udp_timeout` | `2` |
| `dnsdist_max_udp_outstanding` | `65535` |
| `dnsdist_tcp_recv_timeout` | `2` |
| `dnsdist_tcp_send_timeout` | `2` |
| `dnsdist_metrics` | `false` |
| `dnsdist_metrics_bind_addr` | `127.0.0.1` |
| `dnsdist_metrics_bind_port` | `8083` |
| `dnsdist_metrics_require_auth` | `false` |
| `dnsdist_metrics_password` | `admin` |

## Scope

| Where you set it | What it affects |
|------------------|-----------------|
| `inventory/group_vars/client_nodes/lb.yml` | Client traffic LB and client DNSdist |
| `inventory/group_vars/server_nodes/lb.yml` | Server DNSdist |
| `inventory/group_vars/all/` | Applies everywhere, so use it carefully |

If you set `dnsdist: true` in `all`, it will try to enable DNSdist on both client and server nodes.
