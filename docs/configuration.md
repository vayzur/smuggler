# Configuration Reference

All tunnel definitions live in `tunnels:`. Smuggler is built around defaults, so most deployments only need host mapping and a handful of tunnel fields.

## Inventory Layout

| File | Purpose |
|------|---------|
| `inventory/hosts.yml` | SSH hosts and `client_nodes` / `server_nodes` groups |
| `inventory/group_vars/all/tunnels.yml` | Tunnel list |
| `inventory/group_vars/client_nodes/*.yml` | Client-side LB and client DNSdist |
| `inventory/group_vars/server_nodes/*.yml` | Server-side DNSdist, proxies, and Xray |

## Required Tunnel Keys

| Key | Required | Notes |
|-----|----------|-------|
| `name` | yes | Service name suffix |
| `client_node` | yes | Must match a host in `client_nodes` |
| `server_node` | yes | Must match a host in `server_nodes` |
| `engine` | yes | `vaydns`, `slipstream`, or `dnstt` |
| `domain` | yes | Delegated tunnel domain |

## Top-Level Feature Flags

| Key | Default | Scope |
|-----|---------|-------|
| `load_balancing` | `false` | Client traffic LB via nftables |
| `dnsdist` | `false` | Client or server DNSdist, depending on group vars |
| `ssh_proxy` | `false` | Server-side SSH SOCKS proxies |
| `xray` | `false` | Server-side Xray install and service |

## Base Tunnel Defaults

| Key | Default | Notes |
|-----|---------|-------|
| `client.bind_addr` | `0.0.0.0` | Local listener address |
| `client.lb.enabled` | `false` | Enables backup backend swapping |
| `client.lb.backup_addr` | `127.0.0.1` | Backup address for health failover |
| `client.lb.backup_port` | `client.bind_port` | Backup port for health failover |
| `client.health_check.enabled` | `false` | Timer-driven health checks |
| `client.health_check.interval` | `10s` | Timer period |
| `client.health_check.boot_delay` | `10s` | Wait before first run |
| `client.health_check.proxy_type` | `socks5h` | Passed to `curl -x` |
| `client.health_check.proxy_addr` | `127.0.0.1` | Tunnel listener address |
| `client.health_check.proxy_port` | `client.bind_port` | Tunnel listener port |
| `client.health_check.test_url` | `http://www.google.com/gen_204` | Probe target |
| `client.health_check.timeout` | `7` | Seconds before probe fails |
| `client.health_check.retries` | `2` | Probe attempts before failover |
| `server.bind_addr` | `ansible_default_ipv4.address` | Server listener address |
| `server.bind_port` | `53` | Server listener port |
| `server.target_addr` | `127.0.0.1` | Egress target address |
| `server.killer.enabled` | `false` | Optional restart timer |
| `server.killer.interval` | `30min` | Restart cadence |
| `server.killer.boot_delay` | `1min` | Wait before first restart |

## Engine Defaults

### Slipstream

| Key | Default | Notes |
|-----|---------|-------|
| `client.bind_port` | `5201` | Local listener |
| `client.dns_resolver` | `8.8.8.8:53` | String or list |
| `client.keep_alive_interval` | `200` | Milliseconds |
| `server.target_port` | `5201` | Upstream target |
| `server.max_connections` | `512` | Server-side cap |
| `server.idle_timeout_seconds` | `60` | Server idle timeout |

### Dnstt

| Key | Default | Notes |
|-----|---------|-------|
| `client.bind_port` | `7000` | Local listener |
| `client.dns_protocol` | `udp` | Passed to the client binary |
| `client.dns_resolver` | `8.8.8.8:53` | Single resolver string |
| `server.target_port` | `8000` | Upstream target |
| `server.mtu` | `1232` | Tunnel MTU |

### Vaydns

| Key | Default | Notes |
|-----|---------|-------|
| `client.bind_port` | `2584` | Local listener |
| `client.udp_timeout` | `500ms` | Client-side UDP timeout |
| `client.idle_timeout` | `10s` | Client idle timeout |
| `client.keepalive` | `2s` | Client keepalive interval |
| `client.open_stream_timeout` | `10s` | Open stream timeout |
| `client.reconnect_max` | `30s` | Reconnect ceiling |
| `client.reconnect_min` | `1s` | Reconnect floor |
| `client.session_check_interval` | `500ms` | Session check cadence |
| `client.udp_workers` | `100` | Worker count |
| `client.rps` | `0` | Request rate limiter |
| `client.max_streams` | `0` | Stream cap |
| `client.max_qname_len` | `0` | QNAME length cap |
| `client.max_num_labels` | `2` | Label count cap |
| `client.client_id_size` | `2` | Client ID size |
| `client.dns_record_type` | `txt` | DNS record type |
| `client.dns_resolver` | `8.8.8.8:53` | Resolver string |
| `server.target_port` | `2584` | Upstream target |
| `server.client_id_size` | `2` | Server-side client ID size |
| `server.dns_record_type` | `txt` | Server-side DNS record type |
| `server.log_level` | `warn` | Vaydns server log level |
| `server.idle_timeout` | `10s` | Server idle timeout |
| `server.keepalive` | `2s` | Server keepalive |
| `server.mtu` | `1232` | Tunnel MTU |

## Role Defaults

| Key | Default |
|-----|---------|
| `controller_keys_path` | `~/.smuggler` |
| `keys_path` | `/opt` |
| `dnstt_client_binary_url` | Latest dnstt client release |
| `dnstt_server_binary_url` | Latest dnstt server release |
| `vaydns_client_binary_url` | `v0.2.4` release URL |
| `vaydns_server_binary_url` | `v0.2.4` release URL |
| `slipstream_client_binary_url` | `v2026.02.22.1` release URL |
| `slipstream_server_binary_url` | `v2026.02.22.1` release URL |
| `dnstt_pubkey` | `dnstt.pub` |
| `dnstt_privkey` | `dnstt.key` |
| `vaydns_pubkey` | `vaydns.pub` |
| `vaydns_privkey` | `vaydns.key` |
| `slipstream_pubkey` | `slipstream.pub` |
| `slipstream_privkey` | `slipstream.key` |
| `ssh_proxy` | `false` |
| `ssh_privkey` | `smuggler_ed25519` |
| `xray` | `false` |
| `xray_archive_url` | `v26.2.6` release URL |
| `xray_dir` | `/opt/xray` |

## Notes

- `slipstream` accepts a string or list in `client.dns_resolver`.
- `dnstt` and `vaydns` use a single resolver string.
- `server.bind_addr` defaults to the server's primary IPv4 address unless you override it.
- `load_balancing`, `dnsdist`, `ssh_proxy`, and `xray` are group-level switches. Set them in the matching `client_nodes` or `server_nodes` group vars, not in `all`, unless you want them everywhere.
