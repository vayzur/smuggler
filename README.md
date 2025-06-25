# Smuggler

Smuggler is an Ansible-based automation tool that helps you set up a secure DNS tunnel using [dnstt](https://www.bamsoftware.com/software/dnstt). This tunnel lets you bypass internet censorship by disguising your traffic as normal DNS queries.

## What Does This Do?

DNSTT creates a tunnel that makes your internet traffic look like DNS requests. This is useful when:
- You're behind a firewall that blocks most traffic but allows DNS
- You want to bypass internet censorship
- You need a stealthy way to tunnel traffic through restrictive networks

## Architecture Overview

There are two ways to use this:

### Option 1: Direct Connection
- You connect directly to the server from your device
- Only need to set up the server part
- Good for personal use

### Option 2: Server-to-Server Tunnel
- Set up both a server and client on separate machines
- Creates a tunnel between two servers
- Good for serving multiple users or more complex setups

## ⚠️ Important Setup Notes

- **Client setup is optional**: Only configure the client if you want a server-to-server tunnel
- **Only add dnstt_client to your hosts file when setting up the tunnel between two servers**
- **For direct connections**: Skip client configuration and connect directly to the server
- **Supported systems**: Only x86_64 architecture on Debian/Ubuntu 22.04 or 24.04

---

## 📋 Requirements

### What You Need
- **Server**: A Linux server outside the censored network (Debian/Ubuntu 22/24, x86_64)
- **Client** (optional): Another Linux server inside the censored network (Debian/Ubuntu 22/24, x86_64)
- **Control machine**: Your computer running Ansible (Linux/WSL2)
- **Domain**: A domain name you control
- **DNS provider**: Access to configure DNS records

### Software Requirements
- **Control Machine:**
  - Linux (or WSL2 on Windows)
  - Python 3.11 or newer
  - Ansible 2.14 or newer
  - SSH key access to your servers

---

## 🌐 DNS Setup (Required First Step)

Before running the automation, you must configure DNS records. This tells the internet that your server handles DNS requests for your tunnel domain.

### DNS Records to Create

Go to your DNS provider and create these records:

| Record Type | Name             | Value                     | Purpose |
|-------------|------------------|---------------------------|---------|
| A           | tns.example.com  | `<your_server_ipv4>`     | Points to your server |
| AAAA        | tns.example.com  | `<your_server_ipv6>`     | Points to your server (IPv6) |
| NS          | t.example.com    | `tns.example.com`        | Delegates DNS queries to your server |

### Example
If your domain is `mydomain.com` and server IP is `203.0.113.1`:
- A record: `tns.mydomain.com` → `203.0.113.1`
- NS record: `t.mydomain.com` → `tns.mydomain.com`

The `t.mydomain.com` part is your tunnel domain that clients will use.

کامل‌ترین کار اینه که اون قسمت README رو به این شکل اضافه کنیم، درست بعد از بخش "Building DNSTT Binaries":

---

## 🏗️ Precompiled Binaries (Recommended)

You don't need to build anything yourself.
Precompiled binaries for **Linux x86\_64** are already included and ready to use:

```
smuggler/
├── roles/
│   ├── server/files/dnstt-server      ✅ already included
│   └── client/files/dnstt-client      ✅ already included
```

> These are statically compiled and work on most modern Linux systems.  
> You only need to build manually if you're using a different architecture or want to customize the binary.

---

## 🔨 Building DNSTT Binaries (optional — precompiled binaries already included)

Smuggler includes precompiled DNSTT binaries for Linux (x86_64), so in most cases, you don’t need to build anything.
However, if you're running on a different architecture or want to compile from source, follow the steps below.

### Step 1: Get the Source Code
```bash
git clone https://www.bamsoftware.com/git/dnstt.git
cd dnstt
```

### Step 2: Build Server Binary
```bash
cd dnstt-server
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dnstt-server -ldflags="-s -w -extldflags '-static'"
```

### Step 3: Build Client Binary (if needed)
```bash
cd ../dnstt-client
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dnstt-client -ldflags="-s -w -extldflags '-static'"
```

### Step 4: Place Files in Correct Locations
```
smuggler/
├── roles/
│   ├── server/files/dnstt-server    ← Put server binary here
│   └── client/files/dnstt-client    ← Put client binary here (if using client)
```

---

## 📝 Configuration Guide

### Step 1: Get Smuggler
```bash
git clone https://github.com/vayzur/smuggler.git
cd smuggler
```

### Step 2: Configure Your Servers

Edit `inventory/hosts.yml` to define your servers:

**For server-only setup:**
```yaml
all:
  vars:
    ansible_port: 22          # SSH port (change if different)
    ansible_user: root        # SSH user
  hosts:
    dnstt_server:
      ansible_host: 203.0.113.1    # Your server's IP address
```

**For server + client setup:**
```yaml
all:
  vars:
    ansible_port: 22
    ansible_user: root
  hosts:
    dnstt_server:
      ansible_host: 203.0.113.1    # Server Node IP (outside censorship)
    dnstt_client:
      ansible_host: 3.81.52.20     # Client Node IP (inside censorship)
```

### Step 3: Configure Global Settings

Edit `inventory/group_vars/all/all.yml`:

```yaml
# The domain where DNS queries will be sent
# This should match the NS record you created (t.example.com)
dnstt_domain: t.mydomain.com
```

### Step 4: Configure Server Settings

Edit `inventory/group_vars/all/server.yml`:

```yaml
# Where the server should forward decrypted traffic
dnstt_forward_addr: 127.0.0.1    # Usually localhost
dnstt_forward_port: 22           # SSH port, or your proxy port

# Examples of what to forward to:
# - SSH: 127.0.0.1:22
# - SOCKS proxy: 127.0.0.1:1080
# - HTTP proxy: 127.0.0.1:8080
```

**What this means:** When someone sends traffic through the tunnel, the server will forward it to this address and port.

### Step 5: Configure Client Settings (Optional)

Only edit `inventory/group_vars/all/client.yml` if you're setting up a client server:

```yaml
# DNS resolution method
dnstt_dns_mode: "udp" # Options: "udp", "dot", "doh"

# DNS server to use for resolving tunnel domain
dnstt_client_resolver: "217.218.155.155:53" # Any public DNS server

# Where the client listens for connections
dnstt_client_addr: 0.0.0.0 # Listen on all interfaces
dnstt_client_port: 8080    # Port to listen on
```

**What this means:**
- `dnstt_dns_mode`: How to send DNS queries (UDP is fastest, DOT/DOH are more secure)
- `dnstt_client_resolver`: Which DNS server to use for tunnel queries
- `dnstt_client_addr/port`: Where your applications connect to use the tunnel

---

## 🚀 Running the Setup

### Deploy Everything (Server + Client)
```bash
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

### Deploy Only Server
```bash
ansible-playbook -i inventory/hosts.yml playbooks/server.yml
```

### Deploy Only Client
```bash
ansible-playbook -i inventory/hosts.yml playbooks/client.yml
```

---

## 🔧 Optional Features

### Rate Limiting
Control how much bandwidth the tunnel uses.

Create `inventory/group_vars/all/rate.yml`:
```yaml
# Total bandwidth available
total_bandwidth: 1000mbit

# Bandwidth allocated to DNSTT tunnel
dnstt_rate: 2mbit

# Traffic shaping algorithm
qdisc: fq_codel
```

### SSH SOCKS Proxy
Automatically set up a SOCKS proxy on the server.

Create `inventory/group_vars/all/proxy.yml`:
```yaml
proxy:
  enabled: true    # Creates a SSH SOCKS proxy
```

---

## 🧪 Testing Your Setup

### 1. Check if DNS Server is Running
On your server:
```bash
ss -unlp | grep 53
```
You should see the DNSTT server listening on port 53.

### 2. Test DNS Delegation
From any computer:
```bash
dig @8.8.8.8 t.mydomain.com NS
```
This should return your server as the nameserver.

### 3. Test the Tunnel
**For direct connection:**
Configure your application to use your server IP and the forward port.

**For client setup:**
Configure your application to use the client IP and client port.

## ⚠️ Important Notes

- **DNS resolvers** must support recursive queries (most public ones do)
- **Stability varies** depending on your ISP and DNS resolver quality
- **Performance** is slower than direct connections due to DNS overhead
- **Stealth** comes at the cost of speed - this is for bypassing censorship, not high-speed browsing

---

## 🆘 Troubleshooting

### Common Issues

**"Connection refused"**
- Check if the server is running: `systemctl status smuggler.service`
- Verify firewall allows port 53: `iptables -nL`

**"DNS resolution failed"**
- Verify your NS record is working: `dig @8.8.8.8 t.mydomain.com NS`
- Check DNS propagation (can take up to 24 hours)

**"Tunnel not working"**
- Verify the forward address is correct and service is running
- Check server logs: `journalctl -u dnstt-server -f`

---

## 📚 Credits

- [DNSTT by David Fifield](https://www.bamsoftware.com/software/dnstt)
