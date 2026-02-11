# Getting Started

## Requirements

**Control machine (where you run Ansible):**
- Ansible >= 2.10
- SSH client

**Target nodes (client and server):**
- Debian or RedHat-based Linux
- Python 3
- SSH access with sudo privileges

---

## Installation

```bash
git clone https://github.com/vayzur/smuggler.git
cd smuggler
```

---

## Minimal Setup

### 1. Define your hosts

`inventory/hosts.yml`:

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

### 2. Define your tunnels

`inventory/group_vars/all/tunnels.yml`:

```yaml
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t.example.com
```

### 3. Configure DNS

Before deploying, add these DNS records for your domain:

```
t.example.com.     NS    ns.example.com.
ns.example.com.    A     <server_public_ip>
```

See [dns-setup.md](dns-setup.md) for details.

### 4. Deploy

```bash
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

That's it. Smuggler will:
- Download and install the engine binaries
- Generate and distribute keys
- Create and start systemd services
- Configure the tunnel on both client and server

---

## Verify it's working

On the client node, test the tunnel as an HTTP proxy:

```bash
curl -x http://127.0.0.1:5201 http://www.google.com/gen_204
```

A `204` response means the tunnel is up.

---

## Next steps

- Add health checking → [health-check.md](health-check.md)
- Load balance across multiple tunnels → [load-balancing.md](load-balancing.md)
- Use an SSH proxy on the server → [proxy.md](proxy.md)
- Full configuration reference → [configuration.md](configuration.md)
