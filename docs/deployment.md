# Deployment

This guide covers deploying Smuggler infrastructure.

## Prerequisites

Before deploying:

- ✅ [Infrastructure configured](configuration.md) in `hosts.yml` and `tunnels.yml`
- ✅ [DNS records created](dns-setup.md) for tunnel domains
- ✅ SSH access to all nodes verified
- ✅ Ansible installed on control machine

## Quick Deploy

Deploy everything (servers + clients):
```bash
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

## Deployment Modes

### 1. Full Deployment (Recommended)

Deploy all servers and clients:
```bash
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

**What happens:**
1. Connects to all nodes via SSH
2. Downloads tunnel binaries from GitHub
3. Installs system dependencies
4. Configures systemd services
5. Configures load balancing (if enabled)
6. Starts all tunnel services

### 2. Server-Only Deployment

Deploy only tunnel servers:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/server.yml
```

**Use cases:**
- Server configuration changed
- Adding new servers
- Debugging server-side issues

### 3. Client-Only Deployment

Deploy only tunnel clients:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/client.yml
```

**Use cases:**
- Client configuration changed
- Testing different client settings
- Updating load balancing rules

### 4. Targeted Deployment

Deploy to specific nodes:
```bash
# Single node
ansible-playbook -i inventory/hosts.yml smuggler.yml --limit=server1

# Multiple nodes
ansible-playbook -i inventory/hosts.yml smuggler.yml --limit=server1,client1

# All servers
ansible-playbook -i inventory/hosts.yml smuggler.yml --limit=server_nodes

# All clients
ansible-playbook -i inventory/hosts.yml smuggler.yml --limit=client_nodes
```

### 5. Dry Run (Check Mode)

Preview changes without applying:
```bash
ansible-playbook -i inventory/hosts.yml smuggler.yml --check --diff
```

Shows:
- Files that would be created/modified
- Services that would restart
- Configuration changes

## First-Time Deployment

### Step-by-Step

1. **Verify configuration**
```bash
   # Test SSH connectivity
   ansible all -i inventory/hosts.yml -m ping
   
   # Verify syntax
   ansible-playbook -i inventory/hosts.yml smuggler.yml --syntax-check
```

2. **Run dry-run**
```bash
   ansible-playbook -i inventory/hosts.yml smuggler.yml --check --diff
```

3. **Deploy**
```bash
   ansible-playbook -i inventory/hosts.yml smuggler.yml
```

4. **Verify services**
```bash
   # Check all tunnels started
   ansible client_nodes -i inventory/hosts.yml -a "systemctl status 'smuggler@*'"
```

5. **Test connectivity**
```bash
   # From client node
   curl --proxy socks5h://127.0.0.1:7000 https://ifconfig.me
```

## Updating Configuration

### Updating Tunnel Parameters

1. Edit `inventory/group_vars/all/tunnels.yml`
2. Redeploy affected nodes:
```bash
   # If only client config changed
   ansible-playbook -i inventory/hosts.yml playbooks/client.yml --tags client-tunnels
   
   # If only server config changed
   ansible-playbook -i inventory/hosts.yml playbooks/server.yml --tags server-tunnels
```

### Updating Load Balancing

1. Edit `inventory/group_vars/client_nodes/lb.yml`
2. Redeploy clients:
```bash
   ansible-playbook -i inventory/hosts.yml playbooks/client.yml --tags lb-config
```

### Adding New Tunnels

1. Add tunnel definition to `tunnels.yml`
2. Create DNS records for new domain
3. Deploy:
```bash
   ansible-playbook -i inventory/hosts.yml smuggler.yml
```

## Binary Management

Smuggler automatically downloads precompiled binaries from GitHub releases.

**Download locations:**
- dnstt: https://github.com/0xAFz/dnstt/releases
- slipstream: https://github.com/0xAFz/slipstream-rust/releases

**Binaries installed to:**
- `/usr/local/bin/dnstt-server`
- `/usr/local/bin/dnstt-client`
- `/usr/local/bin/slipstream-server`
- `/usr/local/bin/slipstream-client`

**Force binary re-download:**
```bash
# Remove existing binaries
ansible all -i inventory/hosts.yml -a "rm -f /usr/local/bin/*tt* /usr/local/bin/slipstream*"

# Redeploy
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

## Deployment Output

Successful deployment shows:
```
PLAY RECAP *********************************************************************
server1  : ok=15   changed=8    unreachable=0    failed=0    skipped=2
client1  : ok=12   changed=6    unreachable=0    failed=0    skipped=1
```

**Key metrics:**
- `ok`: Tasks completed successfully
- `changed`: Configuration changes applied
- `unreachable`: SSH connection failed (should be 0)
- `failed`: Task errors (should be 0)

## Verification

### Check Service Status
```bash
# On client nodes
systemctl status 'smuggler@*'

# Expected output:
● smuggler@tun0.service - Smuggler DNS Tunnel: tun0
   Active: active (running)
```

### Test Tunnel Connectivity
```bash
# HTTP proxy test
curl --proxy http://127.0.0.1:5201 https://ifconfig.me

# SOCKS5 proxy test
curl --proxy socks5h://127.0.0.1:5201 https://ifconfig.me

# Should return your tunnel server's IP
```

### View Logs
```bash
# Real-time logs
journalctl -u smuggler@tun0 -f

# Last 50 lines
journalctl -u smuggler@tun0 -n 50

# All tunnels
journalctl -u 'smuggler@*' -f
```

## Common Deployment Issues

### SSH Connection Failed

**Error:**
```
UNREACHABLE! => {"changed": false, "msg": "Failed to connect"}
```

**Solutions:**
- Verify IP address in `hosts.yml`
- Check SSH keys: `ssh-add ~/.ssh/id_rsa`
- Test manual connection: `ssh root@server-ip`
- Verify firewall allows SSH (port 22)

### Binary Download Failed

**Error:**
```
failed: [server1] (item=dnstt-server) => {"msg": "Failed to download binary"}
```

**Solutions:**
- Check internet connectivity on target node
- Verify GitHub is accessible
- Check `/tmp/` has write permissions
- Manually download and place in `/usr/local/bin/`

### Service Failed to Start

**Error:**
```
fatal: [client1]: FAILED! => {"msg": "Service smuggler@tun0 failed to start"}
```

**Solutions:**
- Check logs: `journalctl -u smuggler@tun0 -n 50`
- Verify binary exists: `ls -l /usr/local/bin/`
- Check configuration: `cat /etc/systemd/system/smuggler@tun0.service`
- Test binary manually: `/usr/local/bin/slipstream-client --help`

### Port Already in Use

**Error in logs:**
```
bind: address already in use
```

**Solutions:**
- Check what's using the port: `sudo netstat -tlnp | grep :7000`
- Kill conflicting process or change `bind_port`
- Ensure each tunnel has unique port if multiple on same node

## Best Practices

1. **Always test SSH first**
```bash
   ansible all -i inventory/hosts.yml -m ping
```

2. **Use dry-run for major changes**
```bash
   ansible-playbook -i inventory/hosts.yml smuggler.yml --check --diff
```

3. **Deploy servers before clients**
```bash
   ansible-playbook -i inventory/hosts.yml playbooks/server.yml
   ansible-playbook -i inventory/hosts.yml playbooks/client.yml
```

4. **Verify DNS before client deployment**
```bash
   dig NS t.example.com
```

5. **Monitor logs during first deployment**
```bash
   # Terminal 1: Deploy
   ansible-playbook -i inventory/hosts.yml smuggler.yml
   
   # Terminal 2: Watch logs
   ssh client1 "journalctl -u 'smuggler@*' -f"
```

---

## Next Steps

- [Manage running services](operations.md)
- [Monitor tunnel health](operations.md#monitoring)
- [Troubleshoot issues](troubleshooting.md)
