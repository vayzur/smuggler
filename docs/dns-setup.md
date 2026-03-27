# DNS Setup

For DNS tunneling to work, your tunnel domain must be delegated to the server that runs the tunnel engine or DNSdist.

## What you need

For each tunnel domain, create:

| Record | Example | Purpose |
|--------|---------|---------|
| `NS` | `t.example.com. NS ns.example.com.` | Delegates the tunnel subdomain |
| `A` | `ns.example.com. A 203.0.113.10` | Points the nameserver name at your server |

Add the records at your registrar or authoritative DNS provider for the parent domain. Do not add them on the Smuggler server itself.

## Example

```text
t.example.com.      NS   ns.example.com.
ns.example.com.     A    203.0.113.10
```

If your DNS provider will not create glue for a subdomain, use a different hostname outside the delegated zone:

```text
t.example.com.          NS   tunnel-ns.example.com.
tunnel-ns.example.com.  A    203.0.113.10
```

## Multiple domains

Each tunnel can use its own domain:

```text
s.example.com.     NS   ns1.example.com.
ns1.example.com.   A    203.0.113.10

d.example.com.     NS   ns2.example.com.
ns2.example.com.   A    203.0.113.10
```

Both can point at the same server IP. Smuggler routes traffic by domain.

## Verify delegation

Confirm delegation from a machine that is not your server:

```bash
dig NS t.example.com
dig A www.google.com @ns.example.com
```

The first command should return your delegated nameserver. The second command should at least reach your server, even if it does not resolve a normal public name.

To watch live DNS traffic on the server:

```bash
tcpdump -i any -n port 53
```

## Port 53 ownership

| Mode | Listener on port 53 |
|------|---------------------|
| No server DNSdist | The tunnel engine binds directly to `53` |
| Server DNSdist enabled | DNSdist owns `53` and forwards to tunnel instances on loopback |

Make sure nothing else is using port 53 on the server. Common conflicts: `systemd-resolved`, BIND, or Unbound.

```bash
ss -ulnp | grep ':53'
```

If `systemd-resolved` is running, disable it or change its listen address before deploying.
