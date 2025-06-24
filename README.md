# Smuggler

Smuggler is an automation tool to set up stealthy DNSTT (DNS tunnel) between internal (e.g., censored) and external (e.g., uncensored) Linux servers.

## ⚙️ Requirements

### Tunnel Setup

You need one (or more) Linux-based servers:

* **Server Node** (typically outside censorship)
* **Client Node** (typically inside censorship/NAT) (Optional)

### Control Machine (your system running Ansible):

* Python ≥ 3.11
* Ansible
* SSH access to both server and client nodes

If you're on **Windows**, use **WSL2** (Ubuntu preferred) as your Ansible controller.

## 🏗️ Build (Static Binaries)

1. Clone the DNSTT source:

```bash
git clone https://www.bamsoftware.com/git/dnstt.git
cd dnstt
````

2. Build the **server** binary:

```bash
cd dnstt-server

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dnstt-server -ldflags="-s -w -extldflags '-static'"
```

3. Build the **client** binary:

```bash
cd dnstt-client

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dnstt-client -ldflags="-s -w -extldflags '-static'"
```

4. Place the binaries in the appropriate Ansible role directories:

```
roles/
├── server/files/dnstt-server
└── client/files/dnstt-client
```

## 🚀 Deploy

### 1. Clone Smuggler

```bash
git clone https://github.com/vayzur/smuggler.git
cd smuggler
```

### 2. Prepare Inventory

Edit the inventory variables:

```bash
vim inventory/group_vars/all/all.yml
```

Example `all.yml`:

```yaml
dnstt_domain: ns.example.com
```

```bash
vim inventory/group_vars/all/server.yml
```

Example `server.yml`:

```yaml
dnstt_forward_addr: "127.0.0.1:8000"
```

```bash
vim inventory/group_vars/all/client.yml
```

Example `client.yml`:

```yaml
## dot, doh, udp
dnstt_dns_mode: "udp"

## https://doh.domain.tld/dns-query, dot.domain.tld:853, 1.1.1.1
dnstt_client_resolver: 217.218.155.155

dnstt_client_listen_addr: "0.0.0.0:7000"
```

### 3. Ensure DNS (53) port is open on server:

```bash
ss -unlp | grep 53
```

### 4. Run the Playbooks

```bash
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

## Credits

- [dnstt](https://www.bamsoftware.com/software/dnstt)
