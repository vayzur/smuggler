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

| Capability | What you get |
|-----------|--------------|
| Multi-engine support | `vaydns`, `slipstream`, and `dnstt` in one inventory |
| Defaults-first config | Minimal tunnel definitions work out of the box |
| Systemd-native services | Per-tunnel units, timers, and restarts managed by Ansible |
| Health checking | Timer-driven probes with automatic failover and recovery |
| Client-side balancing | nftables traffic distribution plus optional client DNSdist |
| Server-side balancing | DNSdist pools by domain and distributes queries across instances |
| Proxy egress | SSH SOCKS proxies or Xray on server nodes |
| Operational hygiene | Key generation, binary installation, and sysctl tuning |

## Requirements

| Machine | Requirements |
|---------|--------------|
| Control machine | Ansible >= 2.10, SSH client |
| Target nodes | Debian/RedHat-based Linux, Python 3, SSH access with sudo |

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
- [vaydns](https://github.com/net2share/vaydns)
- [dnstt](https://www.bamsoftware.com/software/dnstt/) by David Fifield
- [slipstream-rust](https://github.com/Mygod/slipstream-rust)
