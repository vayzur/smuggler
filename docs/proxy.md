# SSH Proxies

Smuggler can create SSH SOCKS proxy services on server nodes. These give tunnel clients a proxy endpoint without configuring any external proxy software.

**Disabled by default.**

---

## How it works

When you define proxies under `server.proxy`, Smuggler creates a systemd service per proxy entry that runs an SSH `-D` (dynamic SOCKS) forward. The tunnel's `target_addr:target_port` points at this SOCKS listener, so traffic flowing through the tunnel exits via SSH.

---

## Enabling

In `inventory/group_vars/server_nodes/proxy.yml`:

```yaml
ssh_proxy: true
ssh_privkey: "smuggler_ed25519"    # key file in ~/.ssh/ on the server node
```

Then in your tunnel definition:

```yaml
tunnels:
  - name: tun0
    client_node: lb0
    server_node: node0
    engine: slipstream
    domain: t.example.com
    server:
      target_addr: 127.0.0.1
      target_port: 2052
      proxy:
        - name: p1
          remote_host: 127.0.0.1  # SSH server to connect to
          remote_port: 22          # SSH port
```

The proxy creates a SOCKS5 listener on `target_addr:target_port`. The tunnel forwards traffic to it, and SSH forwards it onward.

---

## Multiple proxies

You can define multiple proxy entries. Each becomes its own systemd service:

```yaml
server:
  proxy:
    - name: p1
      remote_host: 127.0.0.1
      remote_port: 22
    - name: p2
      remote_host: 10.0.0.5
      remote_port: 2222
```

---

## SSH connection parameters

These are baked into the service and not configurable via DSL (they're hardcoded to safe defaults):

| Parameter | Value |
|-----------|-------|
| `ServerAliveInterval` | 3s |
| `ServerAliveCountMax` | 3 |
| `ExitOnForwardFailure` | yes |
| `ConnectTimeout` | 10s |
| `StrictHostKeyChecking` | no |
| `NoHostAuthenticationForLocalhost` | yes |

The private key is read from `~/.ssh/<ssh_privkey>` on the server node. The default key name is `smuggler_ed25519`.

---

## Defaults

| Key | Default |
|-----|---------|
| `ssh_proxy` | `false` |
| `ssh_privkey` | `smuggler_ed25519` |
| `proxy[].remote_host` | `127.0.0.1` |
| `proxy[].remote_port` | `ansible_port` (the SSH port Ansible uses to connect) |

---

## Consistency requirement with traffic LB

When traffic load balancing is active across multiple server nodes, all servers **must** use the same proxy type. Mixing SSH proxy on one server and a different proxy (e.g. Xray) on another will break load balancing — the tunnel backends become inconsistent from the client's perspective.
