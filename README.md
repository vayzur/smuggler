# Smuggler

Production-grade DNS tunneling automation framework powered by Ansible.

Define your infrastructure in YAML, deploy with one command.

## What is DNS tunneling?

DNS tunneling encapsulates traffic inside DNS queries and responses — useful when only DNS traffic is allowed through a network or VPNs are blocked.

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

## Features

- **Multi-engine support.** slipstream (QUIC-based, Rust) and dnstt (UDP/DoH/DoT, Go) — pick per tunnel.
- **Client-side load balancing.** Kernel-level traffic distribution across tunnel instances via nftables. DNS resolver distribution via DNSdist. Both are independent, both are optional.
- **Server-side load balancing.** DNSdist in front of tunnel instances — multi-instance per domain, multi-domain on the same server, zone-based query routing.
- **Health checking.** Per-tunnel, systemd timer-driven. Automatic failover to a backup tunnel on failure, automatic recovery when the tunnel comes back.
- **SSH SOCKS proxies.** Server-side, managed by Ansible. No external proxy configuration needed.
- **Declarative config.** One YAML file defines your entire infrastructure. Sane defaults everywhere — override only what you need.
- **Systemd-native.** Every tunnel, proxy, and health checker runs as an independent managed service.

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
