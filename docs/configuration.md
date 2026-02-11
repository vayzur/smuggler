# Configuration Reference

All tunnels are defined in `inventory/group_vars/all/tunnels.yml`. The file name doesn't matter but the location does.

Role-level defaults can be overridden per group:

| Scope | Path |
|-------|------|
| All nodes | `inventory/group_vars/all/` |
| Client nodes only | `inventory/group_vars/client_nodes/` |
| Server nodes only | `inventory/group_vars/server_nodes/` |

---

## Tunnel Definition

Each tunnel is an entry in the `tunnels` list.

### Minimal

```yaml
tunnels:
  - name: tun0
    client_node: client1
    server_node: server1
    engine: slipstream
    domain: t.example.com
```

Smuggler fills in all other values from defaults.

### Full Reference

```yaml
tunnels:
  - name: tun0                   # unique name, used for service names
    client_node: client1         # must match a host in inventory
    server_node: server1         # must match a host in inventory
    engine: slipstream           # slipstream | dnstt
    domain: t.example.com        # DNS domain for this tunnel

    client:
      bind_addr: 0.0.0.0         # address to listen on
      bind_port: 5201            # port to listen on
      dns_protocol: udp          # udp | doh | dot  (dnstt only)
      dns_resolver: "8.8.8.8:53" # single string, or list (slipstream only)
      keep_alive_interval: 200   # ms  (slipstream only)
      extra_cmdline: ""          # appended verbatim to the start command

      lb:
        enabled: false
        backup_addr: 127.0.0.1
        backup_port: 5202

      health_check:
        enabled: false
        interval: "3s"
        boot_delay: "10s"
        proxy_type: http         # proxy protocol to test through
        proxy_addr: 127.0.0.1
        proxy_port: 5201
        test_url: "http://www.google.com/gen_204"
        timeout: 3               # seconds

    server:
      bind_addr: "{{ ansible_default_ipv4.address }}"
      bind_port: 53
      target_addr: 127.0.0.1    # where tunnel forwards traffic
      target_port: 5201
      mtu: 1232                  # dnstt only
      max_connections: 512       # slipstream only
      idle_timeout_seconds: 3    # slipstream only
      extra_cmdline: ""          # appended verbatim to the start command

      proxy:                     # SSH SOCKS proxies (see proxy.md)
        - name: p1
          remote_host: 127.0.0.1
          remote_port: 22
```

---

## Engine Differences

Some fields are engine-specific and silently ignored if you set them on the wrong engine.

| Field | slipstream | dnstt |
|-------|-----------|-------|
| `client.dns_resolver` | string or list | string only |
| `client.keep_alive_interval` | ✓ | — |
| `client.dns_protocol` | — | ✓ (udp/doh/dot) |
| `server.max_connections` | ✓ | — |
| `server.idle_timeout_seconds` | ✓ | — |
| `server.mtu` | — | ✓ |

---

## Client Defaults

| Field | Default |
|-------|---------|
| `client.bind_addr` | `0.0.0.0` (dnstt), not used same way for slipstream |
| `client.bind_port` | `7000` (dnstt) / `5201` (slipstream) |
| `client.dns_resolver` | `8.8.8.8:53` |
| `client.dns_protocol` | `udp` |
| `client.keep_alive_interval` | `200` |
| `client.lb.enabled` | `false` |
| `client.lb.backup_addr` | `127.0.0.1` |
| `client.health_check.enabled` | `false` |
| `client.health_check.interval` | `3s` |
| `client.health_check.boot_delay` | `10s` |
| `client.health_check.test_url` | `http://www.google.com/gen_204` |
| `client.health_check.timeout` | `3` |

## Server Defaults

| Field | Default |
|-------|---------|
| `server.bind_addr` | `ansible_default_ipv4.address` |
| `server.bind_port` | `53` |
| `server.target_addr` | `127.0.0.1` |
| `server.target_port` | `5201` (slipstream) / `7000` (dnstt) |
| `server.mtu` | `1232` (dnstt) |
| `server.max_connections` | `512` (slipstream) |
| `server.idle_timeout_seconds` | `3` (slipstream) |

---

## Binary and Key Defaults

These live in role defaults and can be overridden in group_vars.

### Client role

| Key | Default |
|-----|---------|
| `keys_path` | `/opt` |
| `controller_keys_path` | `~/.smuggler` |
| `dnstt_client_binary_url` | GitHub releases (latest) |
| `slipstream_client_binary_url` | GitHub releases (v2026.02.05) |
| `dnstt_pubkey` | `dnstt.pub` |
| `dnstt_privkey` | `dnstt.key` |
| `dnstt_GOGC` | `10` |
| `dnstt_GOMEMLIMIT` | `512MiB` |

### Server role

| Key | Default |
|-----|---------|
| `keys_path` | `/opt` |
| `controller_keys_path` | `~/.smuggler` |
| `dnstt_server_binary_url` | GitHub releases (latest) |
| `slipstream_server_binary_url` | GitHub releases (v2026.02.05) |
| `dnstt_pubkey` | `dnstt.pub` |
| `dnstt_privkey` | `dnstt.key` |
| `slipstream_pubkey` | `slipstream.pub` |
| `slipstream_privkey` | `slipstream.key` |
| `dnstt_GOGC` | `10` |
| `dnstt_GOMEMLIMIT` | `512MiB` |

`GOGC` and `GOMEMLIMIT` are Go runtime environment variables injected into the systemd service for dnstt. They control garbage collection aggressiveness and memory limit respectively.

---

## Multiple Tunnels on the Same Domain

You can run multiple tunnels with the same domain. On the server side, DNSdist pools them together and load balances queries across all instances for that domain. See [load-balancing.md](load-balancing.md) for setup.

## Multiple Tunnels, Different Domains

Each domain routes to its own pool. You can mix engines:

```yaml
tunnels:
  - name: t0
    engine: slipstream
    domain: s.example.com
    ...
  - name: t1
    engine: dnstt
    domain: d.example.com
    ...
```

## Limitations

- Smuggler has no delete/teardown tasks. To remove a tunnel, stop and delete its systemd service on the target node manually.
- All changes require re-running the playbook to take effect.
