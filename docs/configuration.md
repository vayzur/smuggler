# Configuration Guide

Smuggler uses a declarative YAML-based DSL to define tunnel infrastructure.

## Configuration Files
```
inventory/
├── hosts.yml                    # Server/client IP addresses
└── group_vars/
    ├── all/
    │   └── tunnels.yml          # Tunnel definitions
    └── client_nodes/
        └── lb.yml               # Load balancing (optional)
```

## Infrastructure Definition (hosts.yml)

Define your server and client nodes.

**Location**: `inventory/hosts.yml`
```yaml
all:
  vars:
    ansible_port: 22              # SSH port
    ansible_user: root            # SSH user

  hosts:
    server1:
      ansible_host: 203.0.113.10  # Replace with actual IP
    server2:
      ansible_host: 203.0.113.11
    client1:
      ansible_host: 198.51.100.5

  children:
    server_nodes:                 # Machines running tunnel servers
      hosts:
        server1:
        server2:

    client_nodes:                 # Machines running tunnel clients
      hosts:
        client1:
```

**Test connectivity:**
```bash
ansible all -i inventory/hosts.yml -m ping
```

---

## Tunnel Configuration (tunnels.yml)

Define your tunnels using the Smuggler DSL.

**Location**: `inventory/group_vars/all/tunnels.yml`

### Minimal Configuration
```yaml
---
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t.example.com
```

**Default values applied:**
- Client binds to `0.0.0.0:5201` (slipstream) / `0.0.0.0:7000` (dnstt)
- DNS resolver: `8.8.8.8:53`
- Server listens on primary IP, port 53
- Server forwards to `127.0.0.1:5201` (slipstream) / `127.0.0.1:7000` (dnstt)

---

## Engine Default Ports

> [!WARNING]
> Smuggler uses different default ports based on the tunnel engine. Understanding these defaults is essential for multi-tunnel configurations.

### Default Port Mapping

| Engine | Client `bind_port` | Server `target_port` | Notes |
|--------|-------------------|---------------------|-------|
| **dnstt** | `7000` | `7000` | Used when not explicitly specified |
| **slipstream** | `5201` | `5201` | Used when not explicitly specified |

### How Defaults Work

**Single tunnel example (defaults applied):**
```yaml
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: dnstt
    domain: t.example.com
```

**Effective configuration:**
- Client listens on: `0.0.0.0:7000` (dnstt default)
- Server forwards to: `127.0.0.1:7000` (dnstt default)

**With slipstream:**
```yaml
tunnels:
  - name: tun0
    engine: slipstream
```

**Effective configuration:**
- Client listens on: `0.0.0.0:5201` (slipstream default)
- Server forwards to: `127.0.0.1:5201` (slipstream default)

### Multiple Tunnels - Port Conflicts

> [!WARNING]
> When running multiple tunnels on the same node, you **MUST** specify unique ports to avoid conflicts.

**Wrong (will fail):**
```yaml
tunnels:
  - name: tun0
    client_node: client1
    engine: dnstt    # Default: 7000
  - name: tun1
    client_node: client1
    engine: dnstt    # Default: 7000 - CONFLICT!
```

**Correct:**
```yaml
tunnels:
  - name: tun0
    client_node: client1
    engine: dnstt
    client:
      bind_port: 7000  # Explicit
    server:
      target_port: 7000
      
  - name: tun1
    client_node: client1
    engine: dnstt
    client:
      bind_port: 7001  # Different port
    server:
      target_port: 7001
```

### Mixed Engine Configuration

Different engines can coexist on the same node since they use different default ports:
```yaml
tunnels:
  - name: tun_dnstt
    client_node: client1
    engine: dnstt
    # Uses 7000 by default
    
  - name: tun_slipstream
    client_node: client1
    engine: slipstream
    # Uses 5201 by default - no conflict
```

### Best Practices

1. **Always specify ports explicitly** when running multiple tunnels:
```yaml
   client:
     bind_port: 8080  # Clear and explicit
   server:
     target_port: 8080
```

2. **Use sequential port ranges** for organization:
```yaml
   # Tunnel 0: 8080
   # Tunnel 1: 8081
   # Tunnel 2: 8082
```

3. **Document your port allocation** in comments:
```yaml
   tunnels:
     - name: tun0
       client:
         bind_port: 7000  # Primary dnstt tunnel
     - name: tun1
       client:
         bind_port: 7001  # Backup dnstt tunnel
```

---

## Advanced Configuration

### Full Configuration Example
```yaml
---
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: dnstt
    domain: t.example.com
    
    client:
      # Local binding
      bind_addr: 0.0.0.0
      bind_port: 7000           # Required if >1 tunnel per node
      
      # DNS settings
      dns_protocol: udp         # Options: udp, doh, dot
      dns_resolver: "8.8.8.8:53"
      
      # Health monitoring
      health_check:
        enabled: true
        interval: "3s"
        proxy_type: http        # Options: http, socks5
        proxy_addr: 127.0.0.1
        proxy_port: 7000
        test_url: "http://www.google.com/gen_204"
        timeout: 5
      
      # Load balancing (advanced)
      lb:
        enabled: false
        backup_addr: 127.0.0.1
        backup_port: 7001       # Required if lb.enabled=true
    
    server:
      bind_addr: "{{ ansible_default_ipv4.address }}"
      bind_port: 53
      target_addr: 127.0.0.1
      target_port: 7000
      mtu: 1232

      # SSH SOCKS5 Proxy (optional)
      proxy:
        - name: p1
          remote_host: 127.0.0.1
          remote_port: 22

  - name: tun1
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: s.example.com
    
    client:
      bind_addr: 0.0.0.0
      bind_port: 5201           # Required
      dns_resolver: "1.1.1.1:53"
      keep_alive_interval: 200
      
      health_check:
        enabled: false
      
      lb:
        enabled: false
        backup_addr: 127.0.0.1
        backup_port: 5202       # Required if lb.enabled=true
    
    server:
      bind_addr: "{{ ansible_default_ipv4.address }}"
      bind_port: 53
      target_addr: 127.0.0.1
      target_port: 5201
      max_connections: 512
      idle_timeout_seconds: 3

      # SSH SOCKS5 Proxy (optional)
      proxy:
        - name: p1
          remote_host: 127.0.0.1
          remote_port: 22
```

---

## Configuration Reference

### Common Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Unique tunnel identifier |
| `client_node` | string | Yes | Client hostname from `hosts.yml` |
| `server_node` | string | Yes | Server hostname from `hosts.yml` |
| `engine` | string | Yes | `dnstt` or `slipstream` |
| `domain` | string | Yes | DNS subdomain for tunnel |

### Client Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `bind_addr` | IP | No | `0.0.0.0` | Local address for proxy |
| `bind_port` | port | **Yes** (if >1 tunnel) | `5201` (slipstream) / `7000` (dnstt) | Local proxy port |
| `dns_protocol` | string | No | `udp` | DNS protocol: `udp`, `doh`, `dot` |
| `dns_resolver` | string | No | `8.8.8.8:53` | DNS server to query |

#### Client - Health Check

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `health_check.enabled` | boolean | No | `false` | Enable health monitoring |
| `health_check.interval` | string | No | `3s` | Check interval |
| `health_check.proxy_type` | string | No | `http` | `http` or `socks5` |
| `health_check.proxy_addr` | IP | Yes (if enabled) | - | Proxy address to test |
| `health_check.proxy_port` | port | Yes (if enabled) | - | Proxy port to test |
| `health_check.test_url` | URL | No | `http://www.google.com/gen_204` | Test URL |
| `health_check.timeout` | seconds | No | `3` | Connection timeout |

#### Client - Load Balancing

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `lb.enabled` | boolean | No | `false` | Enable per-tunnel LB |
| `lb.backup_addr` | IP | Yes (if enabled) | - | Backup address |
| `lb.backup_port` | port | Yes (if enabled) | - | Backup port |

### Server Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `bind_addr` | IP | No | `{{ ansible_default_ipv4.address }}` | Listen address |
| `bind_port` | port | No | `53` | Listen port |
| `target_addr` | IP | No | `127.0.0.1` | Backend service IP |
| `target_port` | port | No | `5201` (slipstream) / `7000` (dnstt) | Backend service port |

#### Server - SSH SOCKS5 Proxies

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `proxy[].name` | string | Yes | - | Forward identifier |
| `proxy[].remote_host` | IP | No | `127.0.0.1` | Remote host |
| `proxy[].remote_port` | port | No | `22` | Remote port |

> [!WARNING]
> `proxy[].remote_port` **MUST** be specify if SSH port is not default 

### Engine-Specific Parameters

#### dnstt

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `mtu` | integer | `1232` | Maximum transmission unit |

#### slipstream

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `keep_alive_interval` | integer | `200` | Keep-alive interval (ms) |
| `max_connections` | integer | `512` | Connection pool size |
| `idle_timeout_seconds` | integer | `3` | Idle connection timeout |

---

## Configuration Tips

### Single Tunnel Per Node
If each client node runs only **one** tunnel, minimal config works:
```yaml
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t.example.com
```

### Multiple Tunnels Per Node
**Always** specify `bind_port` for each tunnel:
```yaml
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t0.example.com
    client:
      bind_port: 5201  # Must specify

  - name: tun1
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t1.example.com
    client:
      bind_port: 5202  # Must specify

  - name: tun2
    client_node: client1
    server_node: server2
    engine: dnstt
    domain: t2.example.com
    client:
      bind_port: 7000  # Must be unique

  - name: tun3
    client_node: client1
    server_node: server2
    engine: dnstt
    domain: t3.example.com
    client:
      bind_port: 7001  # Must be unique
```

### Using Different DNS Resolvers
```yaml
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t0.example.com
    client:
      bind_port: 5201
      dns_resolver: "8.8.8.8:53"

  - name: tun1
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t1.example.com
    client:
      bind_port: 5202
      dns_resolver: "1.1.1.1:53"

  - name: tun2
    client_node: client1
    server_node: server2
    engine: dnstt
    domain: t2.example.com
    client:
      bind_port: 7000
      dns_resolver: "9.9.9.9:53"

  - name: tun3
    client_node: client1
    server_node: server2
    engine: dnstt
    domain: t3.example.com
    client:
      bind_port: 7001
      dns_resolver: "4.2.2.4:53"
```

### Enabling Health Checks
```yaml
client:
  health_check:
    enabled: true
    interval: "5s"
    proxy_type: http
    proxy_addr: 127.0.0.1
    proxy_port: 5201    # Can be same with client.bind_port
    test_url: "http://www.google.com/gen_204"
    timeout: 5
```

**Requirements:**
- Backend proxy must be running at `target_addr:target_port`

---

## Next Steps

- [Set up DNS records](dns-setup.md)
- [Configure load balancing](load-balancing.md)
- [Deploy your tunnels](deployment.md)
