# Operations

## Service Names

| Component | Service name |
|-----------|--------------|
| Tunnel | `smuggler@<name>` |
| Health check timer | `health-smuggler@<name>.timer` |
| Health check service | `health-smuggler@<name>.service` |
| SSH proxy | `proxy@<tunnel>-<proxy>` |
| Xray | `xray` |
| Traffic LB | `lb-smuggler.service` |
| Client DNSdist | `dnsdist` |
| Server DNSdist | `dnsdist` |

## Deploy

```bash
# Full deployment
ansible-playbook -i inventory/hosts.yml smuggler.yml

# Client nodes only
ansible-playbook -i inventory/hosts.yml smuggler.yml --limit client_nodes

# Server nodes only
ansible-playbook -i inventory/hosts.yml smuggler.yml --limit server_nodes

# Dry run
ansible-playbook -i inventory/hosts.yml smuggler.yml --check
```

## Manage Services

```bash
systemctl start smuggler@tun0
systemctl stop smuggler@tun0
systemctl restart smuggler@tun0
systemctl status smuggler@tun0
journalctl -u smuggler@tun0 -f
```

Health checks use a timer + oneshot service:

```bash
systemctl status health-smuggler@tun0.timer
systemctl start health-smuggler@tun0.service
journalctl -u health-smuggler@tun0.service -f
```

## Check Connectivity

Replace `5201` with the tunnel's `client.bind_port` if you are checking a different engine or custom port.

```bash
curl -x http://127.0.0.1:5201 http://www.google.com/gen_204 -v
```

If you are using SOCKS:

```bash
curl -x socks5://127.0.0.1:5201 http://www.google.com/gen_204 -v
```

A `204 No Content` response means the tunnel is working.

## Logs

```bash
journalctl -u smuggler@tun0 -n 100
journalctl -u smuggler@tun0 -b
journalctl -u 'smuggler@*' -f
```

## Update

Edit `inventory/group_vars/all/tunnels.yml` or the group vars that control LB, DNSdist, proxying, or Xray, then run the playbook again. Smuggler updates the unit files and restarts the affected services.

## Remove

Smuggler does not have delete tasks. To remove a tunnel:

1. Stop and disable the tunnel and health checker on the target node.
2. Remove the unit files from `/etc/systemd/system/`.
3. Run `systemctl daemon-reload`.
4. Remove the tunnel entry from inventory so the next playbook run does not recreate it.
