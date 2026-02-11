# DNS Setup

For DNS tunneling to work, your domain's DNS queries must be delegated to your server. The server runs the tunnel engine which answers those queries.

---

## Required DNS records

For each tunnel domain (e.g. `t.example.com`):

```
t.example.com.     NS    ns.example.com.
ns.example.com.    A     <your_server_public_ip>
```

This tells the internet: "queries for `t.example.com` should go to `ns.example.com`, which lives at your server's IP."

You add these records at your **domain registrar or authoritative DNS provider** for `example.com` — not on your server.

---

## How to add them

The exact steps depend on your DNS provider, but you're adding two records:

1. An `NS` record on `t.example.com` pointing to `ns.example.com`
2. An `A` record on `ns.example.com` pointing to your server's IP

Some providers call the second record a "glue record." If your provider doesn't let you add a glue record for a subdomain, use a different hostname for the nameserver that's outside the delegated zone:

```
t.example.com.      NS    tunnel-ns.example.com.
tunnel-ns.example.com.  A  <your_server_public_ip>
```

---

## Multiple domains

Each tunnel can use a different domain. Add NS + A records for each one:

```
s.example.com.     NS    ns1.example.com.
ns1.example.com.   A     203.0.113.10

d.example.com.     NS    ns2.example.com.
ns2.example.com.   A     203.0.113.10
```

Both can point at the same server IP. Smuggler (or DNSdist) routes queries to the correct tunnel engine based on the domain.

---

## Verifying DNS delegation

After adding records, confirm delegation is working from a machine that is **not** your server:

```bash
# Check NS delegation
dig NS t.example.com

# Check that queries reach your server
dig A www.google.com @ns.example.com
```

The first command should return your NS record. The second will likely fail (your server only handles tunnel queries, not general DNS) but the important thing is that the query reaches your server.

To check if your server is actually receiving queries:

```bash
# On the server (requires tcpdump)
tcpdump -i any -n port 53
```

Then send a DNS query for the domain from another machine and watch for it in the capture.

---

## Server-side: what listens on port 53

- **Without server LB**: The tunnel engine (slipstream or dnstt) binds directly to `0.0.0.0:53`
- **With server LB** (`dnsdist: true`): DNSdist binds to `0.0.0.0:53` and forwards to tunnel instances on loopback

Make sure nothing else is using port 53 on the server. Common conflicts: `systemd-resolved`, a pre-existing BIND/Unbound install.

```bash
# Check what's on port 53
ss -ulnp | grep ':53'
```

If `systemd-resolved` is running, disable it or change its listen address before deploying.
