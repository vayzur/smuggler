# 🏴‍☠️ Smuggler

**Smuggler** is a powerful, Ansible-driven automation framework designed to deploy and manage stealthy DNS tunnels across distributed networks.

Whether you are bypassing restrictive firewalls, navigating censored environments, or establishing covert communication channels, Smuggler automates the complex heavy lifting of configuring DNS engines and kernel-level load balancing.

---

## ✨ Key Features

* **Multi-Engine Support**: No longer limited to just `dnstt`.
* **Kernel-Level Load Balancing**: High-performance client-side balancing using **Linux nftables** (`hash`, `random`, or `roundrobin`).
* **Declarative Configuration**: Define your entire infrastructure (multiple servers and clients) in simple YAML files.
* **Systemd Integration**: Every tunnel is managed as an independent, templated systemd service (`smuggler@tun_name.service`).
* **Flexible Architecture**: Deploy one server to many clients, or many servers to a single load-balanced entry point.

---

## 🚀 Supported Engines

Smuggler supports multiple tunnel backends, each serving a specific purpose in your infrastructure:

* **dnstt**: Legacy support. Included for compatibility, though it lacks modern performance and bypass features.
* **dnstt-revived**: This version is built to bypass aggressive filtering by giving you granular control over the DNS query structure.
  * **Bypass NXDOMAIN**: Use `max_qname_len` (e.g., `101`) and `max_num_labels` to satisfy strict resolvers that block or fail on non-standard query lengths.
* **slipstream-rust**: **High Performance.** A modern, **Rust-based** engine designed for maximum throughput. This is the fastest choice for high-speed tunneling when aggressive obfuscation isn't the primary concern.

---

## 🛠️ Prerequisites & Binary Setup

To keep the repository lightweight and secure, **precompiled binaries are no longer included.** You must provide the binaries for the engines you intend to use.

### 1. Requirements

* **Control Machine**: A Linux/macOS machine with [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) installed.
* **Target Nodes**: Remote servers running a Debian-based Linux distribution (Ubuntu/Debian) with SSH access.

### 2. Manual Binary Placement

Download or compile your chosen engines and place the binaries in the following directories before running the deployment:

| Engine | Server Binary Path | Client Binary Path |
| --- | --- | --- |
| **dnstt** | `roles/server/files/dnstt-server` | `roles/client/files/dnstt-client` |
| **dnstt-revived** | `roles/server/files/dnstt-revived-server` | `roles/client/files/dnstt-revived-client` |
| **slipstream** | `roles/server/files/slipstream-server` | `roles/client/files/slipstream-client` |

---

## 📂 Project Structure

```bash
inventory/
├── group_vars/
│   ├── all/
│   │   ├── all.yml            # Global Ansible settings
│   │   └── tunnels.yml        # THE CORE: Define your tunnels here
│   └── client_nodes/
│       └── lb.yml             # Load balancer (nftables) configuration
└── hosts.yml                  # Define your server and client IP addresses

```

---

## 🧩 Step 1: Define Your Infrastructure (`hosts.yml`)

Map your servers. You can have multiple `server_nodes` and `client_nodes` (Load Balancers).

```yaml
all:
  vars:
    ansible_port: 3022
    ansible_user: root

  hosts:
    node0:
      ansible_host: node0.domain.tld
    lb0:
      ansible_host: lb0.domain.tld

  children:
    server_nodes:
      hosts:
        node0:

    client_nodes:
      hosts:
        lb0:

```

---

## 💎 Step 2: Configure Tunnels (`tunnels.yml`)

The tunnel DSL (Domain Specific Language) allows you to mix and match engines. Edit `inventory/group_vars/all/tunnels.yml`:

```yaml
tunnels:
  - name: tun0
    client_node: lb0
    server_node: node0
    engine: dnstt
    domain: d.domain.tld
    client:
      dns_mode: udp
      dns_resolver: "1.1.1.1:53"
      bind_addr: 0.0.0.0
      bind_port: 2052
    server:
      bind_addr: "{{ ansible_default_ipv4.address }}"
      bind_port: 53
      target_addr: 127.0.0.1
      target_port: 2052 # Port where the traffic finally lands
      mtu: 493

  - name: tun1
    client_node: lb0
    server_node: node0
    engine: slipstream
    domain: d.domain.tld
    client:
      dns_resolver: "1.1.1.1:53"
      bind_port: 2052
      keep_alive_interval: 200
    server:
      bind_port: 53
      target_addr: 127.0.0.1
      target_port: 2052

  - name: tun2
    client_node: lb0
    server_node: node0
    engine: dnstt-revived
    domain: d.domain.tld
    client:
      dns_mode: udp
      dns_resolver: "1.1.1.1:53"
      bind_addr: 0.0.0.0
      bind_port: 2052
      max_num_labels: 2
      max_qname_len: 101
      rps: 0
      udp_workers: 100
      loglevel: "warning"
    server:
      bind_addr: "{{ ansible_default_ipv4.address }}"
      bind_port: 53
      target_addr: 127.0.0.1
      target_port: 2052
      mtu: 493
      loglevel: "warning"

```

---

## ⚖️ Step 3: Load Balancing (Optional)

If you want the client node to distribute traffic across multiple tunnels using the Linux kernel, configure `inventory/group_vars/client_nodes/lb.yml`:

```yaml
lb_enabled: true
lb:
  type: "roundrobin"  # Options: hash, random, roundrobin
  ports:
    - "8080"          # Traffic to 8080 will be balanced across tunnels
    - "4100-4200"     # Ranges are also supported
    - "> 10000"

```

---

## 🌐 Step 4: DNS Setup (Crucial)

DNS tunnels require specific records to route traffic to your server.

| Record Type | Name | Value | Purpose |
| --- | --- | --- | --- |
| **A** | `tns.domain.com` | `1.2.3.4` (Server IP) | Points to your tunnel server |
| **NS** | `d.domain.com` | `tns.domain.com` | Delegates the tunnel domain to your server |

---

## 🚀 Step 5: Deployment

Once your configuration is set and binaries are in place, run the playbook:

**Deploy Everything:**

```bash
ansible-playbook -i inventory/hosts.yml smuggler.yml

```

**Deploy Only Servers:**

```bash
ansible-playbook -i inventory/hosts.yml playbooks/server.yml

```

**Deploy Only Clients:**

```bash
ansible-playbook -i inventory/hosts.yml playbooks/client.yml

```

---

## 🧪 Monitoring & Troubleshooting

### Check Service Status

Each tunnel gets its own systemd unit based on the `name` field in your YAML:

```bash
systemctl status smuggler@tun0.service

```

### View Real-time Logs

```bash
journalctl -u smuggler@tun0.service -f

```

### Verify DNS Traffic

Run this on your server to see if DNS queries are hitting the tunnel:

```bash
tcpdump -n i any udp port 53

```

---

## ⚠️ Important Notes

* **MTU**: DNS tunnels have overhead; ensure your application handles small MTU sizes (usually around 500-1200).
* **Resolver**: Use a reliable DNS resolver (like 1.1.1.1) that supports large TXT/CNAME records.
* **Security**: DNS tunneling is often monitored by advanced firewalls. Use `dnstt-revived` or `slipstream` for more modern obfuscation features.

---

## 📚 Credits

* [dnstt](https://www.bamsoftware.com/software/dnstt) by David Fifield.
* [dnstt-revived](https://github.com/net2share/dnstt-revived)
* [slipstream-rust](https://github.com/Mygod/slipstream-rust)
