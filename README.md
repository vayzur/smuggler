# Smuggler

Production-grade DNS tunneling automation framework powered by Ansible.

Define your infrastructure in YAML, deploy with one command.

## What is DNS tunneling?

DNS tunneling encapsulates traffic inside DNS queries and responses — useful when only DNS traffic is allowed through a network or VPNs are blocked.

## Features

### Client
- **Health checking** with automatic failover and configurable backup tunnels
- **Kernel-level traffic load balancing** across tunnel instances (nftables: hash, roundrobin, random)
- **DNS resolver load balancing** across multiple upstream resolvers (DNSdist)
- Per-tunnel systemd services with **self-healing** and fast reconnection

### Server
- **Multi-instance load balancing** per domain (DNSdist)
- **Multi-domain support** — run multiple tunnels with different domains on the same server
- **Zone-based DNS routing** — each domain routes to its own tunnel pool
- **Built-in SSH SOCKS proxies** — no external proxy configuration needed

### Infrastructure
- **Declarative YAML DSL** — define your entire infrastructure in one file
- **Flexible topology** — 1:N, N:1, and N:N deployment patterns
- **Full Ansible automation** — one command to deploy, update, or reconfigure
- **Systemd-native** — every component is a managed, restartable service

## Quick start

```bash
git clone https://github.com/vayzur/smuggler.git
cd smuggler

# Define hosts
vim inventory/hosts.yml

# Define tunnels
vim inventory/group_vars/all/tunnels.yml

# Deploy
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

## Minimal example

**`inventory/hosts.yml`:**
```yaml
all:
  hosts:
    server1:
      ansible_host: 203.0.113.10
    client1:
      ansible_host: 198.51.100.5
  children:
    server_nodes:
      hosts:
        server1:
    client_nodes:
      hosts:
        client1:
```

**`inventory/group_vars/all/tunnels.yml`:**
```yaml
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t.example.com
```

Smuggler handles the rest with defaults.

## Engines

| Engine | Language | Notes |
|--------|----------|-------|
| `slipstream` | Rust | QUIC-based, high performance |
| `dnstt` | Go | UDP/DoH/DoT, widely deployed |

## Requirements

**Control machine:** Ansible >= 2.10, SSH client

**Target nodes:** Debian/RedHat-based Linux, Python 3, SSH access with sudo

## Documentation

- [Getting Started](docs/getting-started.md)
- [DNS Setup](docs/dns-setup.md)
- [Configuration Reference](docs/configuration.md)
- [Load Balancing](docs/load-balancing.md)
- [Health Checking](docs/health-check.md)
- [SSH Proxies](docs/proxy.md)
- [Operations](docs/operations.md)

## Contributing

Contributions welcome! Please open an issue or pull request.

## Credits

Built on top of:
- [dnstt](https://www.bamsoftware.com/software/dnstt/) by David Fifield
- [slipstream-rust](https://github.com/Mygod/slipstream-rust)
