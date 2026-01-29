# Smuggler

**Smuggler** is a production-grade, Ansible-driven automation framework for deploying and managing high-performance DNS tunnels across distributed networks. It abstracts away the complexity of DNS tunnel configuration, kernel-level optimizations, and multi-engine orchestration into simple YAML declarations.

---

## 📋 Table of Contents

- [What is Smuggler?](#what-is-smuggler)
- [Key Features](#-key-features)
- [Architecture Overview](#-architecture-overview)
- [Supported Engines](#-supported-engines)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Binary Setup](#binary-setup)
- [Configuration Guide](#-configuration-guide)
  - [Infrastructure Definition](#1-infrastructure-definition-hostsyml)
  - [Tunnel Configuration](#2-tunnel-configuration-tunnelsyml)
  - [Load Balancing](#3-load-balancing-configuration-optional)
  - [DNS Setup](#4-dns-configuration)
- [Deployment](#-deployment)
- [Advanced Features](#-advanced-features)
  - [End-to-End Health Checks](#end-to-end-health-checks)
- [Credits](#-credits)

---

## What is Smuggler?

Smuggler automates the deployment of DNS tunneling infrastructure, enabling you to:

- **Bypass restrictive firewalls** that only allow DNS traffic
- **Navigate censored environments** where traditional VPNs are blocked
- **Establish covert communication channels** using legitimate DNS protocols
- **Load balance** across multiple tunnel endpoints with kernel-level efficiency

Unlike manual DNS tunnel setups, Smuggler provides:
- Declarative infrastructure-as-code approach
- Multi-engine support with hot-swappable backends
- Production-ready systemd service management
- Built-in health monitoring and failover capabilities

---

## ✨ Key Features

### Core Capabilities
- **Multi-Engine Support**: Choose from `dnstt`, `dnstt-revived`, or `slipstream` based on your performance and stealth requirements
- **Kernel-Level Load Balancing**: High-performance client-side traffic distribution using Linux nftables (`hash`, `random`, or `roundrobin`)
- **Declarative Configuration**: Define entire infrastructure (servers, clients, tunnels) in simple YAML files
- **Systemd Integration**: Each tunnel runs as an independent, templated systemd service (`smuggler@<name>.service`)
- **Flexible Architecture**: Deploy 1:N (one server, many clients) or N:1 (many servers, one load-balanced client)
- **End-to-End Health Checks**: Automated tunnel connectivity verification through proxy endpoints
- **DNS Resolver Scanning**: Test and validate DNS resolvers for tunnel compatibility before deployment
- **Kernel Optimization**: Automatic tuning of kernel parameters for maximum DNS tunnel performance

---

## 🚀 Supported Engines

#### dnstt (Legacy)
- **Purpose**: Baseline DNS tunneling
- **When to Use**: Testing, simple scenarios where performance isn't critical
- **Limitations**: Older codebase, fewer bypass features

#### dnstt-revived (Recommended for Stealth)
- **Purpose**: Advanced evasion of DNS filtering and inspection
- **Key Features**:
  - `max_qname_len`: Control query name length (e.g., 101 bytes) to satisfy strict resolvers
  - `max_num_labels`: Limit DNS label count to bypass NXDOMAIN detection
  - `rps`: Rate limiting to avoid detection
  - `udp_workers`: Concurrent UDP socket handling
- **When to Use**: Environments with aggressive DNS filtering, GFW-style censorship

#### slipstream (Recommended for Performance)
- **Purpose**: High-throughput tunneling with modern codebase
- **Key Features**:
  - Written in Rust for memory safety and speed
  - Optimized connection pooling (`max_connections`)
  - Keep-alive mechanisms (`keep_alive_interval`)
- **When to Use**: High-bandwidth applications, stable network conditions

---

## 🚀 Getting Started

### Prerequisites

#### Control Machine (Your Computer)
- **Operating System**: Linux, macOS, or WSL2 on Windows
- **Software**:
  - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) >= 2.10
    ```bash
    # Ubuntu/Debian
    sudo apt update && sudo apt install ansible
    
    # macOS
    brew install ansible
    
    # Using pip
    pip install ansible
    ```
  - SSH client
  - Git (to clone this repository)

#### Target Nodes (Remote Servers)
- **Operating System**: Debian-based Linux (Ubuntu 22.04+, Debian 12+)
- **Requirements**:
  - SSH access with sudo/root privileges
  - Python 3 installed
  - Minimum 512MB RAM per tunnel
  - Open port 53 (UDP) on server nodes

### Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/vayzur/smuggler.git
   cd smuggler
   ```

2. **Verify Ansible Installation**
   ```bash
   ansible --version
   ```

3. **Test SSH Connectivity**
   ```bash
   # Test connection to your server
   ssh root@your-server-ip
   
   # If using SSH keys, ensure they're loaded
   ssh-add ~/.ssh/id_rsa
   ```

### Binary Setup

**Important**: To keep the repository lightweight and avoid licensing issues, precompiled binaries are **not included**. You must provide them manually.

#### Step 1: Download/Compile Binaries

Choose the engines you need:

**dnstt:**
```bash
# Download from official releases or compile from source
# https://www.bamsoftware.com/software/dnstt/
```

**dnstt-revived:**
```bash
git clone https://github.com/net2share/dnstt-revived.git
cd dnstt-revived
# Follow compilation instructions in their README
```

**slipstream:**
```bash
git clone https://github.com/Mygod/slipstream-rust.git
cd slipstream-rust
cargo build --release
# Binaries will be in target/release/
```

#### Step 2: Place Binaries in Correct Locations

Create the required directory structure and copy binaries:

```bash
# From the smuggler project root
mkdir -p roles/server/files roles/client/files

# Example for dnstt
cp /path/to/dnstt-server roles/server/files/
cp /path/to/dnstt roles/client/files/dnstt-client

# Example for dnstt-revived
cp /path/to/dnstt-revived-server roles/server/files/
cp /path/to/dnstt-revived roles/client/files/dnstt-revived-client

# Example for slipstream
cp /path/to/slipstream-server roles/server/files/
cp /path/to/slipstream-client roles/client/files/
```

**Required Binary Placement:**

| Engine | Server Binary | Client Binary |
|--------|---------------|---------------|
| dnstt | `roles/server/files/dnstt-server` | `roles/client/files/dnstt-client` |
| dnstt-revived | `roles/server/files/dnstt-revived-server` | `roles/client/files/dnstt-revived-client` |
| slipstream | `roles/server/files/slipstream-server` | `roles/client/files/slipstream-client` |

#### Step 3: Make Binaries Executable

```bash
chmod +x roles/server/files/*
chmod +x roles/client/files/*
```

#### Step 4: Verify Binary Placement

```bash
ls -lh roles/server/files/
ls -lh roles/client/files/
```

---

## 📝 Configuration Guide

### Project Structure

```
smuggler/
├── inventory/
│   ├── group_vars/
│   │   ├── all/
│   │   │   ├── all.yml          # Global Ansible settings
│   │   │   └── tunnels.yml      # MAIN CONFIG: Tunnel definitions
│   │   └── client_nodes/
│   │       └── lb.yml            # Load balancer configuration
│   └── hosts.yml                 # Server/client IP addresses
├── playbooks/
│   ├── server.yml                # Server-only deployment
│   └── client.yml                # Client-only deployment
├── roles/
│   ├── server/                   # Server role (tasks, templates, files)
│   └── client/                   # Client role (tasks, templates, files)
└── smuggler.yml                  # Main playbook (deploys everything)
```

### 1. Infrastructure Definition (`hosts.yml`)

Define your server and client nodes. This tells Ansible **where** to deploy.

**Location**: `inventory/hosts.yml`

**Example Configuration:**

```yaml
all:
  vars:
    ansible_port: 22              # SSH port (change if using non-standard)
    ansible_user: root            # SSH user with sudo privileges

  hosts:
    # Define all machines here
    node0:
      ansible_host: 203.0.113.10  # Replace with actual IP or hostname
    node1:
      ansible_host: 203.0.113.11
    lb0:
      ansible_host: 198.51.100.5
    lb1:
      ansible_host: 198.51.100.6

  children:
    # Machines that will run tunnel servers (listening on port 53)
    server_nodes:
      hosts:
        node0:
        node1:

    # Machines that will run tunnel clients (connecting to servers)
    client_nodes:
      hosts:
        lb0:
        lb1:
```

**Testing Your Configuration:**
```bash
# Ping all hosts to verify connectivity
ansible all -i inventory/hosts.yml -m ping

# Should output: node0 | SUCCESS => ...
```

---

### 2. Tunnel Configuration (`tunnels.yml`)

Define **what** tunnels to create and **how** they should behave.

**Location**: `inventory/group_vars/all/tunnels.yml`

**Basic Example (Single Tunnel):**

```yaml
---
tunnels:
  - name: tun0                    # Unique identifier (used in systemd service name)
    client_node: lb0              # Which client node runs this tunnel
    server_node: node0            # Which server node to connect to
    engine: slipstream            # Engine choice: dnstt, dnstt-revived, slipstream
    domain: t.example.com         # DNS subdomain for this tunnel
    
    client:
      dns_resolver: "1.1.1.1:53"  # DNS server to use for queries
      bind_addr: 0.0.0.0          # Local address to bind proxy
      bind_port: 8080             # Local port for applications to connect
      
    server:
      bind_addr: "{{ ansible_default_ipv4.address }}"  # Listen on primary IP
      bind_port: 53               # DNS port (usually 53)
      target_addr: 127.0.0.1      # Where to forward decrypted traffic
      target_port: 8080           # Port of your backend service
```

**Production Example (Multiple Tunnels with Different Engines):**

```yaml
---
tunnels:
  # High-performance tunnel for bulk data transfer
  - name: tun_fast
    client_node: lb0
    server_node: node0
    engine: slipstream
    domain: fast.example.com
    client:
      lb:
        enabled: false
        backup_addr: 127.0.0.1
        backup_port: 2053
      health_check:
        enabled: false # Requires a local proxy to check End-to-End connection
        proxy_type: http
        proxy_addr: 127.0.0.1
        proxy_port: 10001
        test_url: "http://www.google.com/gen_204"
        timeout: 5
      dns_resolver: 
        - "1.1.1.1:53"
        - "8.8.8.8:53"
        - "9.9.9.9:53"
      bind_addr: 0.0.0.0
      bind_port: 8080
      keep_alive_interval: 200
    server:
      bind_addr: "{{ ansible_default_ipv4.address }}"
      bind_port: 53
      target_addr: 127.0.0.1
      target_port: 8080
      max_connections: 512

  # Stealth tunnel for bypassing aggressive filtering
  - name: tun_stealth
    client_node: lb0
    server_node: node1
    engine: dnstt-revived
    domain: stealth.example.com
    client:
      lb:
        enabled: false
        backup_addr: 127.0.0.1
        backup_port: 2053
      health_check:
        enabled: false # Requires a local proxy to check End-to-End connection
        proxy_type: http
        proxy_addr: 127.0.0.1
        proxy_port: 10002
        test_url: "http://www.google.com/gen_204"
        timeout: 5
      dns_protocol: udp           # udp, doh, dot
      dns_resolver: "8.8.8.8:53"
      bind_addr: 0.0.0.0
      bind_port: 1080
      max_num_labels: 2           # Bypass label count restrictions
      max_qname_len: 101          # Satisfy strict query length checks
      rps: 0                      # No rate limiting (0 = unlimited)
      udp_workers: 100            # Concurrent UDP sockets
      loglevel: "warning"
    server:
      bind_addr: "{{ ansible_default_ipv4.address }}"
      bind_port: 53
      target_addr: 127.0.0.1
      target_port: 1080
      mtu: 493                    # Conservative MTU for compatibility
      loglevel: "warning"

  # Backup tunnel on different infrastructure
  - name: tun_backup
    client_node: lb1
    server_node: node1
    engine: dnstt
    domain: backup.example.com
    client:
      lb:
        enabled: false
        backup_addr: 127.0.0.1
        backup_port: 2053
      health_check:
        enabled: false # Requires a local proxy to check End-to-End connection
        proxy_type: http
        proxy_addr: 127.0.0.1
        proxy_port: 10003
        test_url: "http://www.google.com/gen_204"
        timeout: 5
      dns_protocol: udp
      dns_resolver: "9.9.9.9:53"
      bind_addr: 127.0.0.1        # Only local connections
      bind_port: 9090
    server:
      bind_addr: "{{ ansible_default_ipv4.address }}"
      bind_port: 53
      target_addr: 127.0.0.1
      target_port: 9090
      mtu: 493
```

**Configuration Parameters Explained:**

#### Common Parameters (All Engines)
| Parameter | Description | Example |
|-----------|-------------|---------|
| `name` | Unique tunnel identifier | `tun0`, `production_tunnel` |
| `client_node` | Client hostname from `hosts.yml` | `lb0` |
| `server_node` | Server hostname from `hosts.yml` | `node0` |
| `engine` | Tunnel backend | `dnstt`, `dnstt-revived`, `slipstream` |
| `domain` | DNS subdomain for tunnel | `t.example.com` |

#### Client Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `dns_resolver` | string | DNS server to query | `1.1.1.1:53` |
| `bind_addr` | IP | Local address for proxy | `0.0.0.0` |
| `bind_port` | port | Local port for proxy | Required |
| `health_check.enabled` | boolean | Enable end-to-end health monitoring | `false` |
| `health_check.proxy_type` | string | Proxy protocol (`http`/`socks5`) | `http` |
| `health_check.proxy_addr` | IP | Health check target address | `127.0.0.1` |
| `health_check.proxy_port` | port | Health check target port | Required if enabled |
| `health_check.timeout` | seconds | Connection timeout | `5` |

#### Server Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `bind_addr` | IP | Address to listen on | `{{ ansible_default_ipv4.address }}` |
| `bind_port` | port | Port to listen on (usually 53) | `53` |
| `target_addr` | IP | Backend service address | `127.0.0.1` |
| `target_port` | port | Backend service port | Required |

#### Engine-Specific Parameters

**dnstt / dnstt-revived:**
| Parameter | Description | Typical Value |
|-----------|-------------|---------------|
| `dns_protocol` | Transport protocol | `udp`, `doh`, `dot` |
| `mtu` | Maximum transmission unit | `493` (safe default) |
| `max_qname_len` | Max DNS query name length | `101` (bypass filters) |
| `max_num_labels` | Max DNS labels per query | `2` (bypass NXDOMAIN) |
| `rps` | Queries per second limit | `0` (unlimited) |
| `udp_workers` | Concurrent UDP sockets | `100` |
| `loglevel` | Log verbosity | `warning`, `info`, `debug` |

**slipstream:**
| Parameter | Description | Typical Value |
|-----------|-------------|---------------|
| `keep_alive_interval` | Keep-alive interval (ms) | `200` |
| `max_connections` | Connection pool size | `256` - `512` |

---

### 3. Load Balancing Configuration (Optional)

Distribute traffic across multiple tunnels using kernel-level nftables.

**Location**: `inventory/group_vars/client_nodes/lb.yml`

**When to Use Load Balancing:**
- You have multiple tunnel servers for redundancy
- You want to maximize throughput by splitting traffic
- You need failover capabilities

**Configuration:**

```yaml
---
load_balancing: false

lb:
  type: "hash" ## Options: hash, random, roundrobin
  ports:
    - "80"
    - "8080"
    - "8880"
    - "2052"
    - "2082"
    - "2086"
    - "2095"
    - "443"
    - "2053"
    - "2083"
    - "2087"
    - "2096"
    - "8443"
    - "9200-9400"
    - "10000-10200"
```

**Load Balancing Types:**

| Type | Behavior | Use Case |
|------|----------|----------|
| `hash` | Consistent hashing based on source IP/port | Sticky sessions, maintain connection affinity |
| `random` | Random distribution | Simple load spreading |
| `roundrobin` | Sequential distribution | Even distribution, default choice |

> [!WARNING]
> If you want to use client-side load balancing, all server-side proxies must be consistent across every server.
You cannot run Shadowsocks on one server and an SSH SOCKS proxy on another and still expect client-side load balancing to work correctly.
All servers must expose the same type of proxy and behave identically.
In practice, load balancing fundamentally relies on consistency.

---

### 4. DNS Configuration

DNS tunnels require specific DNS records to route traffic to your server.

**Prerequisites:**
- You own a domain (e.g., `example.com`)
- You can add DNS records (via your registrar or DNS provider)
- Your tunnel server has a static IP address

**Required DNS Records:**

| Record Type | Name | Value | TTL | Purpose |
|-------------|------|-------|-----|---------|
| **A** | `ns.example.com` | `203.0.113.10` | 300 | Points to your tunnel server IP |
| **NS** | `t.example.com` | `ns.example.com` | 300 | Delegates tunnel subdomain to your server |

**Step-by-Step Setup:**

1. **Create the A Record (Nameserver Address)**
   - **Name**: `ns.example.com` (or `tns`, `dns`, etc.)
   - **Type**: A
   - **Value**: Your server's public IP (e.g., `203.0.113.10`)
   - **TTL**: 300 (5 minutes)

2. **Create the NS Record (Delegation)**
   - **Name**: `t.example.com` (or your chosen subdomain)
   - **Type**: NS
   - **Value**: `ns.example.com`
   - **TTL**: 300

3. **Verify DNS Propagation**
   ```bash
   # Check if NS record is set correctly
   dig NS t.example.com
   
   # Check if it resolves to your server
   dig @ns.example.com test.t.example.com
   ```

**Multiple Tunnels Example:**

If you have multiple tunnels with different subdomains:

```yaml
# In tunnels.yml
tunnels:
  - name: tun0
    domain: fast.example.com
  - name: tun1
    domain: stealth.example.com
```

**DNS Records:**
```
# A records (point to server IPs)
ns1.example.com.  IN A  203.0.113.10
ns2.example.com.  IN A  203.0.113.11

# NS records (delegate subdomains)
fast.example.com.    IN NS ns1.example.com.
stealth.example.com. IN NS ns2.example.com.
```

**Troubleshooting DNS:**

```bash
# Test if your server receives DNS queries
# Run on server:
sudo tcpdump -i any -n udp port 53

# Test from client:
dig @dns_resolver_ip random.t.example.com
```

---

## 🎯 Deployment

Once configuration is complete, deploy your tunnels.

### Deploy Everything (Servers + Clients)

```bash
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

**What This Does:**
1. Connects to all `server_nodes` and `client_nodes` via SSH
2. Installs system dependencies (if needed)
3. Copies tunnel binaries to `/usr/local/bin/`
4. Creates systemd service files
5. Configures DNS and networking
6. Starts all tunnel services
7. Configures load balancing (if enabled)

### Deploy Only Servers

```bash
ansible-playbook -i inventory/hosts.yml playbooks/server.yml
```

Use when:
- Only server configuration changed
- Adding new servers to existing infrastructure
- Debugging server-side issues

### Deploy Only Clients

```bash
ansible-playbook -i inventory/hosts.yml playbooks/client.yml
```

Use when:
- Only client configuration changed
- Testing different client settings
- Debugging client-side issues

### Deploy Specific Tunnels

```bash
# Deploy only to a specific host
ansible-playbook -i inventory/hosts.yml smuggler.yml --limit=node0

# Deploy only specific roles
ansible-playbook -i inventory/hosts.yml smuggler.yml --tags server --limit=server_nodes
```

### Dry Run (Check Before Deploying)

```bash
# See what would change without applying
ansible-playbook -i inventory/hosts.yml smuggler.yml --check --diff
```

## 🔧 Advanced Features

### End-to-End Health Checks

Health checks verify that tunnels are fully operational by testing connectivity through the entire tunnel path to a backend proxy service.

**How It Works:**
1. Client attempts to connect to specified proxy (HTTP/SOCKS5)
2. Connection routed through tunnel → server → backend proxy
3. If successful within timeout, tunnel marked healthy
4. If failed, tunnel marked unhealthy (can trigger alerts)

**Configuration:**

```yaml
client:
  health_check:
    enabled: true                             # Enable health monitoring
    proxy_type: http                          # 'http' or 'socks5'
    proxy_addr: 127.0.0.1                     # Local proxy address
    proxy_port: 8080                          # Local proxy port
    timeout: 5                                # Connection timeout
```

**Requirements:**
- A running HTTP or SOCKS5 proxy on the server at `target_addr:target_port`

---

## 📊 Operations & Monitoring

### Service Management

Each tunnel runs as an independent systemd service:

**Check Status:**
```bash
# Single tunnel
systemctl status smuggler@tun0.service

# All tunnels
systemctl status 'smuggler@*'
```

**Start/Stop/Restart:**
```bash
# Start
systemctl start smuggler@tun0

# Stop
systemctl stop smuggler@tun0

# Restart
systemctl restart smuggler@tun0

# Enable (start on boot)
systemctl enable smuggler@tun0
```

**View Logs:**
```bash
# Real-time logs
journalctl -u smuggler@tun0 -f

# Last 100 lines
journalctl -u smuggler@tun0 -n 100

# Logs from last hour
journalctl -u smuggler@tun0 --since "1 hour ago"

# All tunnel logs
journalctl -u 'smuggler@*' -f
```

---

## 🔍 Troubleshooting

### Common Issues

#### 1. "Connection Refused" When Testing Tunnel

**Symptoms:**
```bash
curl --proxy socks5h://127.0.0.1:8080 https://example.com
# curl: (7) Failed to connect to 127.0.0.1 port 8080: Connection refused
```

**Diagnosis:**
```bash
# Check if service is running
systemctl status smuggler@tun0

# Check if port is listening
netstat -tlnp | grep 8080
```

**Solutions:**
- Restart service: `systemctl restart smuggler@tun0`
- Check binary exists: `ls -l /usr/local/bin/<engine>-client`
- Review logs: `journalctl -u smuggler@tun0 -n 50`

#### 2. DNS Queries Not Reaching Server

**Symptoms:**
Server logs show no traffic, client connects but no data flow.

**Diagnosis:**
```bash
# On server, monitor for incoming DNS
sudo tcpdump -i any -n udp port 53
```

**Solutions:**
- Verify DNS NS record: `dig NS t.example.com`
- Check firewall on server: `sudo ufw status` or `sudo iptables -L`
- Verify server is listening: `netstat -ulnp | grep :53`
- Test with different DNS resolver in `tunnels.yml`

---

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📚 Credits

This project builds upon the excellent work of:

- **[dnstt](https://www.bamsoftware.com/software/dnstt/)** by David Fifield - Original DNS tunnel implementation
- **[dnstt-revived](https://github.com/net2share/dnstt-revived)** - Enhanced dnstt with filtering bypass capabilities
- **[slipstream-rust](https://github.com/Mygod/slipstream-rust)** - High-performance Rust-based DNS tunnel
