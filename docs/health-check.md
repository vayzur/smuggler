# Health Checking

Each tunnel can have an independent health checker that tests connectivity through the tunnel and triggers failover when it fails.

**Disabled by default.** You must explicitly enable it per tunnel.

---

## How it works

The health checker runs as a systemd timer + oneshot service pair. On each interval it:

1. Makes an HTTP(S) request through the tunnel proxy
2. If the request fails (timeout or error), marks the tunnel as unhealthy
3. If `client.lb.enabled` is true, swaps traffic to the backup address
4. On recovery, swaps back to the main tunnel

The checker fires on a timer (`OnUnitActiveSec`) starting after a boot delay (`OnBootSec`). This gives the tunnel time to establish before the first check.

---

## Enabling health check

```yaml
tunnels:
  - name: tun0
    client_node: lb0
    server_node: node0
    engine: slipstream
    domain: t.example.com
    client:
      bind_addr: 127.0.0.1
      bind_port: 5200
      health_check:
        enabled: true
        interval: "3s"
        boot_delay: "10s"
        proxy_type: http
        proxy_addr: 127.0.0.1
        proxy_port: 5200
        test_url: "http://www.google.com/gen_204"
        timeout: 5
```

The `proxy_addr` and `proxy_port` should point at the tunnel's local listener (same as `client.bind_addr` / `client.bind_port`). The health checker uses this as the proxy to reach `test_url`.

---

## Health check + failover

To use health checking with automatic failover, enable `client.lb` on the tunnel:

```yaml
client:
  bind_addr: 127.0.0.1
  bind_port: 5200
  lb:
    enabled: true
    backup_addr: 127.0.0.1
    backup_port: 5202      # a backup tunnel listening here
  health_check:
    enabled: true
    proxy_type: http
    proxy_addr: 127.0.0.1
    proxy_port: 5200
    test_url: "http://www.google.com/gen_204"
    timeout: 5
```

When the tunnel at `5200` fails, traffic is redirected to `5202` until it recovers. The backup is a separate tunnel instance — it must be running and healthy independently.

---

## All options

| Field | Default | Description |
|-------|---------|-------------|
| `health_check.enabled` | `false` | Must be `true` to activate |
| `health_check.interval` | `3s` | How often to run the check |
| `health_check.boot_delay` | `10s` | Wait after boot before first check |
| `health_check.proxy_type` | *(required)* | Proxy protocol: `http` or `socks5` |
| `health_check.proxy_addr` | `127.0.0.1` | Address of the tunnel's proxy listener |
| `health_check.proxy_port` | `client.bind_port` | Port of the tunnel's proxy listener |
| `health_check.test_url` | `http://www.google.com/gen_204` | URL to test through the proxy |
| `health_check.timeout` | `3` | Seconds before the test is considered failed |

---

## Systemd services

For each tunnel with health checking enabled, Smuggler creates:

- `health-smuggler@<name>.timer` — fires the check on the configured interval
- `health-smuggler@<name>.service` — oneshot service that runs the health script

The timer starts after `boot_delay` and repeats every `interval`. Both are managed by Ansible and tied to the tunnel's lifecycle.

---

## Example: aggressive health checking

For a high-availability setup where fast failover matters:

```yaml
health_check:
  enabled: true
  interval: "2s"
  boot_delay: "5s"
  proxy_type: http
  proxy_addr: 127.0.0.1
  proxy_port: 5200
  test_url: "http://www.google.com/gen_204"
  timeout: 2
```

This checks every 2 seconds and times out in 2 seconds, so you get failover within ~4 seconds of a tunnel going down.
