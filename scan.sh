#!/bin/bash
# End-to-End DNS Scanning
# Tests DNS resolvers for DNS tunneling capability
#
# Usage: ./scan.sh <resolvers_file> <domain> <pubkey> <listen_addr> <proxy> <timeout>
#
# Example:
#   ./scan.sh resolvers.txt t.example.com "publickey" 127.0.0.1:7300 http://127.0.0.1:7300 5

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

show_help() {
  cat << EOF
usage: $0 <resolvers_file> <domain> <pubkey> <listen_addr> <proxy> <timeout>

arguments:
  resolvers_file    file with DNS resolvers (one per line, e.g., 8.8.8.8:53)
  domain            dnstt domain (e.g., t.example.com)
  pubkey            dnstt public key
  listen_addr       local listen address (e.g., 127.0.0.1:7300)
  proxy             socks5 proxy (e.g., http://127.0.0.1:7300, socks5://127.0.0.1:7300)
  timeout           connection timeout in seconds

example:
  $0 resolvers.txt t.example.com "305318d872..." 127.0.0.1:7300 http://127.0.0.1:7300 5

output:
  alive.txt - list of working resolvers
EOF
}

if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  show_help
  exit 0
fi

alive_file="alive.txt"
resolvers_path="${1:?resolver path is required}"
domain="${2:?domain is required}"
pubkey="${3:?dnstt public key is required}"
listen_address="${4:?dnstt-client listen address is required}"
proxy="${5:?proxy is required}"
timeout="${6:?timeout is required}"

cleanup() {
  echo -e "\n${RED}[!] interrupted${NC}"
  pkill -P $$ 2>/dev/null
  exit 1
}

trap cleanup INT TERM

[[ -f "$resolvers_path" ]] || {
  echo "resolver file not found: $resolvers_path" >&2
  exit 1
}

[[ "$timeout" =~ ^[0-9]+$ ]] || {
  echo "timeout must be a number" >&2
  exit 1
}

command -v dnstt-client >/dev/null 2>&1 || {
  echo "dnstt-client not found" >&2
  exit 1
}

echo -e "\ndomain: ${domain}\npubkey: ${pubkey}\nlisten address: ${listen_address}\nproxy: ${proxy}\ntimeout: ${timeout}\n\n"

: > "$alive_file"

while read -r addr; do
  [[ -z "$addr" ]] && continue

  dnstt-client -udp "${addr}" -pubkey "$pubkey" "$domain" "$listen_address" >/dev/null 2>&1 &

  slip_pid=$!

  sleep 1

  curl \
    -x "$proxy" \
    --max-time "$timeout" \
    -s -o /dev/null \
    http://www.google.com/gen_204

  curl_status=$?

  kill -9 "$slip_pid" 2>/dev/null
  wait "$slip_pid" 2>/dev/null

  if [[ "$curl_status" -eq 0 ]]; then
    echo -e "${GREEN}[+] alive:${NC} $addr"
    echo "$addr" >> "$alive_file"
  else
    echo -e "${RED}[-] dead:${NC} $addr"
  fi

done < "$resolvers_path"
