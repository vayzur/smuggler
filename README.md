# Smuggler

Smuggler is an Ansible-based automation system that sets up a stealthy DNS tunnel using [dnstt](https://www.bamsoftware.com/software/dnstt) between a server (typically outside censorship) and an optional client (inside censorship).

---

## ⚙️ Requirements

### Server and Client Nodes

- Linux-based servers (Debian/Ubuntu)
- Root access via SSH (key-based)
- External DNS provider access (for setting up NS, A/AAAA records)

### Control Machine (running Ansible)

- Linux-based system (Use WSL2 if you are on Windows.)
- Python ≥ 3.11
- Ansible ≥ 2.14
- SSH access to server and client nodes

---

## 🌐 DNS Configuration

Before deployment, configure the following DNS records in your DNS provider panel:

| Record Type | Name             | Value                     |
|-------------|------------------|---------------------------|
| A           | tns.example.com  | `<server_public_ipv4>`   |
| AAAA        | tns.example.com  | `<server_public_ipv6>`   |
| NS          | t.example.com    | `tns.example.com`        |

Replace `example.com` with your domain and `tns` with the subdomain of your choice.

---

## ⚒️ Build Static DNSTT Binaries

### 1. Clone the dnstt repo

```bash
git clone https://www.bamsoftware.com/git/dnstt.git
cd dnstt
````

### 2. Build server binary

```bash
cd dnstt-server
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dnstt-server -ldflags="-s -w -extldflags '-static'"
```

### 3. Build client binary

```bash
cd ../dnstt-client
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dnstt-client -ldflags="-s -w -extldflags '-static'"
```

### 4. Move binaries to role directories

```
roles/
├── server/files/dnstt-server
└── client/files/dnstt-client
```

---

## 🕵️ Setup Smuggler

### 1. Clone this repository

```bash
git clone https://github.com/vayzur/smuggler.git
cd smuggler
```

### 2. Edit host inventory

Example `inventory/hosts.yml`:

```yaml
all:
  vars:
    ansible_port: 3022
    ansible_user: root

  hosts:
    dnstt_server:
      ansible_host: 203.11.0.4
    dnstt_client:
      ansible_host: 3.44.2.23
```

### 3. Configure global variables

```bash
vim inventory/group_vars/all/all.yml
```

Example:

```yaml
dnstt_domain: t.example.com
```

### 4. Server configuration

```bash
vim inventory/group_vars/all/server.yml
```

Example:

```yaml
dnstt_forward_addr: 127.0.0.1
dnstt_forward_port: 11882
```

This is where the tunnel will forward traffic (usually your internal SOCKS/HTTP proxy or SSH).

### 5. Client configuration

```bash
vim inventory/group_vars/all/client.yml
```

Example:

```yaml
dnstt_dns_mode: "udp"  # or "dot" or "doh"
dnstt_client_resolver: "217.218.155.155:53"
dnstt_client_addr: 0.0.0.0
dnstt_client_port: 11882
```

---

## 🚀 Deployment

### 1. Deploy full tunnel (server + client)

```bash
ansible-playbook -i inventory/hosts.yml smuggler.yml
```

### 2. Deploy server only

```bash
ansible-playbook -i inventory/hosts.yml playbooks/server.yml
```

---

## 📦 Rate Limiting

You can apply rate limits to the DNSTT tunnel on the client node.

Create or edit:

```bash
vim inventory/group_vars/all/rate.yml
```

Example:

```yaml
total_bandwidth: 1000mbit
dnstt_rate: 2mbit
qdisc: fq_pie
```

---

## 🧦 SSH SOCKS Proxy (Optional)

You can enable a dynamic SOCKS proxy via SSH on the server.

Create:

```bash
vim inventory/group_vars/all/proxy.yml
```

Example:

```yaml
proxy:
  enabled: true
```

---

## 🧪 Verification

Ensure DNS port 53 is open on the server:

```bash
ss -unlp | grep 53
```

Verify that the NS delegation works by querying:

```bash
dig @<your_dns_resolver> t.example.com NS
```

---

## 📝 Notes

* DNS resolvers on the client side must support recursive queries.
* DNSTT is UDP-based and stealthy, but stability can vary depending on ISP and resolver quality.

---

## 🧾 Credits

* [dnstt by David Fifield](https://www.bamsoftware.com/software/dnstt)
