# SSH Proxies

Smuggler can expose tunnel egress through either SSH SOCKS proxies or Xray. Both are server-side features and both are disabled by default.

## SSH SOCKS Proxies

When `ssh_proxy: true`, Smuggler creates a `systemd` service for every `server.proxy` entry. Each service runs `ssh -D` and listens on the tunnel's `server.target_addr:server.target_port`.

### Example

```yaml
ssh_proxy: true
ssh_privkey: smuggler_ed25519

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
          remote_host: 127.0.0.1
          remote_port: 22
```

### Defaults

| Key | Default |
|-----|---------|
| `ssh_proxy` | `false` |
| `ssh_privkey` | `smuggler_ed25519` |
| `proxy[].remote_host` | `127.0.0.1` |
| `proxy[].remote_port` | `ansible_port` |

### SSH options

These SSH flags are baked into the generated service:

| Option | Value |
|--------|-------|
| `ServerAliveInterval` | `3` |
| `ServerAliveCountMax` | `3` |
| `ExitOnForwardFailure` | `yes` |
| `ConnectTimeout` | `10` |
| `StrictHostKeyChecking` | `no` |
| `NoHostAuthenticationForLocalhost` | `yes` |

## Xray

When `xray: true`, Smuggler installs Xray and runs it as a systemd service. The bundled default config exposes a SOCKS inbound on `127.0.0.1:1081`.

### Example

```yaml
xray: true

tunnels:
  - name: t10
    client_node: lb0
    server_node: node0
    engine: dnstt
    domain: t4.example.com
    server:
      target_addr: 127.0.0.1
      target_port: 1081
```

### Defaults

| Key | Default |
|-----|---------|
| `xray` | `false` |
| `xray_dir` | `/opt/xray` |
| `xray_archive_url` | `v26.2.6` release URL |

To customize Xray, place a host-specific JSON file in `roles/xray/files/` or edit `roles/xray/files/default.json`.

## LB Consistency

If you use traffic load balancing across multiple server nodes, keep the proxy type consistent across those nodes. Mixing SSH proxy on one node and Xray on another will break backend symmetry.
