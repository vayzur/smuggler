# Health Checking

Smuggler can run a per-tunnel health checker as a `systemd` timer plus a oneshot service. The checker probes the tunnel through its local proxy and reacts if the probe fails.

## What it does

1. Runs `curl` through the tunnel proxy.
2. Retries the probe if requested.
3. If the probe fails, restarts the tunnel service.
4. If `client.lb.enabled` is set, it also switches the LB backend to the backup address and port.
5. If the probe succeeds again, the LB backend moves back to the primary.

## Example

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
      lb:
        enabled: true
        backup_addr: 127.0.0.1
        backup_port: 5202
      health_check:
        enabled: true
        interval: "5s"
        boot_delay: "10s"
        proxy_type: socks5h
        proxy_addr: 127.0.0.1
        proxy_port: 5200
        test_url: "http://www.google.com/gen_204"
        timeout: 7
        retries: 2
```

## Defaults

| Key | Default |
|-----|---------|
| `health_check.enabled` | `false` |
| `health_check.interval` | `10s` |
| `health_check.boot_delay` | `10s` |
| `health_check.proxy_type` | `socks5h` |
| `health_check.proxy_addr` | `127.0.0.1` |
| `health_check.proxy_port` | `client.bind_port` |
| `health_check.test_url` | `http://www.google.com/gen_204` |
| `health_check.timeout` | `7` |
| `health_check.retries` | `2` |

`proxy_user` and `proxy_pass` are optional. If present, they are embedded into the proxy URL passed to `curl`.

## Services

For each enabled tunnel, Smuggler creates:

| Unit | Purpose |
|------|---------|
| `health-smuggler@<name>.service` | Runs the probe once |
| `health-smuggler@<name>.timer` | Repeats the probe on the configured interval |

## Notes

- Health checking is client-side only.
- If LB is disabled, a failed probe still restarts the tunnel service.
- The checker uses the tunnel's local listener, so the proxy port should match the tunnel service's `client.bind_port`.
