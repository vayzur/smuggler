# Smuggler

**Production-grade DNS tunneling automation framework powered by Ansible**

Smuggler automates the deployment and management of DNS tunnels across distributed networks. Define your infrastructure in YAML, deploy with one command.

## What is DNS Tunneling?

DNS tunneling encapsulates traffic inside DNS queries and responses, enabling you to:
- Bypass restrictive firewalls that only allow DNS traffic
- Navigate censored environments where VPNs are blocked
- Establish covert communication channels using legitimate DNS protocols

## Key Features

- 🚀 **Multi-Engine Support**: `dnstt` or `slipstream` backends
- ⚡ **Kernel-Level Load Balancing**: High-performance traffic distribution using nftables
- 📝 **Declarative Configuration**: Define infrastructure in simple YAML
- 🔧 **Systemd Integration**: Each tunnel runs as an independent service
- 🌐 **DNS Resolver Load Balancing**: Distribute queries across multiple DNS servers
- 💚 **Health Monitoring**: End-to-end connectivity verification
- 🎯 **Flexible Architecture**: 1:N or N:1 deployment patterns

## Quick Start
```bash
# Clone repository
git clone https://github.com/vayzur/smuggler.git
cd smuggler

# Configure infrastructure
vim inventory/hosts.yml
vim inventory/group_vars/all/tunnels.yml

# Deploy
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

## Minimal Example

**hosts.yml:**
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

**tunnels.yml:**
```yaml
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t.example.com
```

That's it! Smuggler handles the rest with intelligent defaults.

## Documentation

- 📖 [Getting Started](docs/getting-started.md) - Prerequisites, installation
- ⚙️ [Configuration Guide](docs/configuration.md) - Complete DSL reference
- 🌐 [DNS Setup](docs/dns-setup.md) - DNS record configuration
- ⚖️ [Load Balancing](docs/load-balancing.md) - Traffic and DNS resolver distribution
- 🚀 [Deployment](docs/deployment.md) - Deployment strategies
- 🔧 [Operations](docs/operations.md) - Service management, monitoring
- 🔍 [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## Requirements

**Control Machine:**
- Ansible >= 2.10
- SSH client

**Target Nodes:**
- Debian/RedHat-based Linux
- Python 3
- SSH access with sudo privileges

## Supported Engines

| Engine | Purpose | When to Use |
|--------|---------|-------------|
| **dnstt** | Baseline DNS tunneling | Simple scenarios, testing |
| **slipstream** | High-performance (Rust) | Production, high-throughput |

## Contributing

Contributions welcome! Please open an issue or pull request.

## Credits

Built on top of:
- [dnstt](https://www.bamsoftware.com/software/dnstt/) by David Fifield
- [slipstream-rust](https://github.com/Mygod/slipstream-rust)
