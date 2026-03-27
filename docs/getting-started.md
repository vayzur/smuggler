# Getting Started

Smuggler is easiest to adopt in two steps: define your hosts, then define your tunnels. The sample inventory under `inventory/sample/` shows the shape of a production deployment with multiple engines, load balancing, health checks, and proxying.

## Requirements

| Machine | Requirements |
|---------|--------------|
| Control machine | Ansible >= 2.10, SSH client |
| Target nodes | Linux, Python 3, SSH access with sudo |

## Inventory Layout

| File | Purpose |
|------|---------|
| `inventory/hosts.yml` | SSH hosts and the `client_nodes` / `server_nodes` groups |
| `inventory/group_vars/all/tunnels.yml` | Tunnel definitions |
| `inventory/group_vars/client_nodes/*.yml` | Client-side extras like traffic LB and local DNSdist |
| `inventory/group_vars/server_nodes/*.yml` | Server-side extras like DNSdist, SSH proxies, and Xray |

## Minimal Setup

1. Define your hosts in `inventory/hosts.yml`.

```yaml
all:
  vars:
    ansible_port: 22
    ansible_user: root
    ansible_python_interpreter: /usr/bin/python3

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

2. Define a tunnel in `inventory/group_vars/all/tunnels.yml`.

```yaml
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t.example.com
```

3. Deploy.

```bash
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

Smuggler installs the chosen engine, generates keys, writes `systemd` units, and starts the services.

## Production Starting Point

If you want a fuller example, use `inventory/sample/` as a reference. It shows:

- multiple tunnels
- mixed engines
- client health checks
- client-side traffic LB
- client-side DNSdist
- server-side DNSdist
- server-side proxying

## Verify

Check the tunnel service on the client node:

```bash
systemctl status smuggler@tun0
```

If the tunnel exposes a local proxy, test it:

```bash
curl -x http://127.0.0.1:5201 http://www.google.com/gen_204
```

Replace `5201` with the tunnel's `client.bind_port` if you are not using the default slipstream port.

## Next Steps

- Use the DNS delegation flow: [DNS Setup](dns-setup.md)
- Review the configuration model and defaults: [Configuration Reference](configuration.md)
- Turn on failover or resolver sharding: [Load Balancing](load-balancing.md)
- Add a health checker: [Health Checking](health-check.md)
- Expose traffic through SSH or Xray: [SSH Proxies](proxy.md)
- Learn the service names and update flow: [Operations](operations.md)
