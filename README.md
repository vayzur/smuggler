# Smuggler

Smuggler is an Ansible-powered deployment system for building and managing secure DNS tunnels using [dnstt](https://www.bamsoftware.com/software/dnstt). It enables traffic tunneling over DNS—perfect for bypassing censorship, firewall restrictions, or creating covert communication paths in hostile networks.

---

## 🚀 Features

- **Declarative Tunnel Setup** — All configuration is defined in YAML, no manual scripting needed
- **Multi-Node Architecture** — Support for multiple client and server nodes across distributed environments
- **Load Balancing (Client & Server Side)** — Choose between `hash`, `random`, or `roundrobin` strategies to distribute traffic
- **Redundancy & High Availability** — If one server fails, others continue to serve the tunnel
- **Per-Tunnel Key Pairs** — Each tunnel uses a unique key pair for enhanced isolation and security
- **Optional Bandwidth Limiting** — Apply precise rate limits using `htb`, with support for fair queuing via `fq_codel`, `cake`, `fq_pie`, and others.
- **SOCKS Proxy via SSH** — Easily proxy traffic over the tunnel using built-in SOCKS5 support
- **Distributed Design** — Per-node behavior is controlled via inventory configuration
- **Self-Healing (Upcoming)** — Automatic recovery from failed nodes via dynamic rule updates

---

## Architecture Overview

Smuggler can operate in multiple modes depending on your needs:

### 🔹 Mode 1: Single Server (Direct Access)
- Ideal for personal use
- Only one server node is deployed
- Tunnel is directly accessible without client-side load balancing

### 🔹 Mode 2: Client/Server Tunnel (Multi-Node)
- Multiple client and server nodes
- Server-side DNS load balancing with DNSTT instances on different ports
- Client-side load balancing to distribute DNS queries across multiple entry points

---

## ⚙️ Inventory Structure

Smuggler uses [Ansible inventory](https://docs.ansible.com/) to manage servers and settings.

```bash
inventory/
├── group_vars/
│   ├── all/
│   │   ├── all.yml            # Global settings
│   │   └── tunnels.yml        # Tunnel definitions
│   ├── client_nodes/
│   │   ├── lb.yml             # Client-side load balancing config
│   │   └── rate.yml           # Client bandwidth throttling
│   └── server_nodes/
│       └── lb.yml             # Server-side load balancing config
├── hosts.yml                  # Node definitions
├── lb.yml                     # LB-only scenario
└── single.yml                 # Single-server scenario
````

---

## 🧠 Tunnel Definition (tunnels.yml)

Tunnel configuration is fully declarative and stored in `group_vars/all/tunnels.yml`.

Each tunnel requires:

* A **unique name**
* A **client\_node** and **server\_node**
* A **domain** delegated via DNS
* A **client** and **server** section with DNS and forwarding parameters

### Example:

```yaml
tunnels:
  - name: t0
    client_node: lb
    server_node: node1
    domain: d.domain.tld
    client:
      dns_mode: udp
      dns_resolver: "8.8.8.8:53"
      bind_addr: 127.0.0.1
      bind_port: 11885
    server:
      bind_addr: "127.0.0.1"
      bind_port: 5301
      forward_addr: 127.0.0.1
      forward_port: 1080
      mtu: 1232
```

> 🔸 **Important**: When using load balancers, client and server tunnel listeners **must bind to `127.0.0.1`** and server ports **must be different from 53** to avoid conflict.

---

## 🧩 hosts.yml Structure

Smuggler detects the node roles using Ansible host groups. Example layout:

### Full Load-Balanced Setup:

```yaml
all:
  vars:
    ansible_port: 3022
    ansible_user: root
  hosts:
    node1:
      ansible_host: node0.domain.tld
    node2:
      ansible_host: node1.domain.tld
    node3:
      ansible_host: node2.domain.tld
    node4:
      ansible_host: node3.domain.tld
    lb1:
      ansible_host: lb1.domain.tld
    lb2:
      ansible_host: lb2.domain.tld

  children:
    server_nodes:
      hosts:
        node1:
        node2:
        node3:
        node4:

    client_nodes:
      hosts:
        lb1:
        lb2:
```

### Minimal Single-Server:

```yaml
all:
  vars:
    ansible_port: 3022
    ansible_user: root
  hosts:
    node1:
      ansible_host: sub.domain.tld
  children:
    server_nodes:
      hosts:
        node1:
```

---

## 🔁 Load Balancing

Enable load balancing by creating `lb.yml` in each node group.

### Client Load Balancer:

`group_vars/client_nodes/lb.yml`:

```yaml
lb_enabled: true
lb:
  type: "random"     # Options: hash, random, roundrobin
  ports:
    - "8080"
    - "2087"
    - "2096"
    - "2095"
    - "4100-4200"
```

### Server Load Balancer:

`group_vars/server_nodes/lb.yml`:

```yaml
lb_enabled: true
lb:
  type: "hash"       # Options: hash, random, roundrobin
  ports:
    - "53"
```

> 🔸 **Client-side load balancer ports** can be any values — Smuggler automatically maps incoming traffic to the correct internal tunnel ports based on `tunnels.yml`.  

> 🔸 **Server-side load balancer ports** must include only `"53"` because DNS queries always target port 53. Smuggler internally handles distribution to the correct tunnel instances. If the list is empty or contains non-53 ports, server-side load balancing will not function.  

> 🔸 Server-side LB only supports UDP (for DNSTT)  

---

## 🌐 DNS Setup (Required First Step)

Before running the automation, you must configure DNS records. This tells the internet that your server handles DNS requests for your tunnel domain.

### DNS Records to Create

Go to your DNS provider and create these records:

| Record Type | Name            | Value                | Purpose                              |
| ----------- | --------------- | -------------------- | ------------------------------------ |
| A           | tns.example.com | `<your_server_ipv4>` | Points to your server                |
| AAAA        | tns.example.com | `<your_server_ipv6>` | Points to your server (IPv6)         |
| NS          | t.example.com   | `tns.example.com`    | Delegates DNS queries to your server |

### Example

If your domain is `mydomain.com` and server IP is `203.0.113.1`:

* A record: `tns.mydomain.com` → `203.0.113.1`
* NS record: `t.mydomain.com` → `tns.mydomain.com`

The `t.mydomain.com` part is your tunnel domain that clients will use.

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

## 🔨 Building DNSTT Binaries (Optional)

Smuggler includes precompiled DNSTT binaries for Linux (x86\_64), so in most cases, you don’t need to build anything.
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

## 🚀 Running the Setup

### Deploy Full Setup (Client + Server)

```bash
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

### Deploy Server Only

```bash
ansible-playbook -i inventory/hosts.yml playbooks/server.yml
```

### Deploy Client Only

```bash
ansible-playbook -i inventory/hosts.yml playbooks/client.yml
```

---

## 🧪 Testing and Monitoring

### Check if DNSTT is Listening

```bash
ss -unlp | grep 53
```

### Check DNS Delegation

```bash
dig @8.8.8.8 t.yourdomain.com NS
```

### Check Tunnel Status

```bash
systemctl status smuggler@tun0.service
```

Smuggler now uses **templated systemd units**, one per tunnel:

* `smuggler@tun0.service`
* `smuggler@tun1.service`
* etc.

---

## ⚠️ Notes & Limitations

- DNS resolvers must support recursive queries
- DNS changes (NS/A records) may take time to propagate
- Performance is limited by DNS packet size and latency
- This is a stealth tunnel, not a high-speed VPN

---

## 🆘 Troubleshooting

### Connection Refused

* Check if tunnel service is running:
  `systemctl status smuggler@tun0.service`
* Ensure firewall allows UDP 53

### DNS Resolution Fails

* Check NS record: `dig @8.8.8.8 t.domain.com NS`
* Wait for DNS propagation

### Tunnel Not Working

* Check forward port and service
* Inspect logs: `journalctl -u smuggler@tun0.service -f`

---

## 📚 Credits

* [DNSTT by David Fifield](https://www.bamsoftware.com/software/dnstt)
