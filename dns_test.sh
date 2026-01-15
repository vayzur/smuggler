#!/bin/bash
# dns_test.sh - Test public DNS resolvers speed & reachability
# Run: chmod +x dns_test.sh && ./dns_test.sh

# List of DNS servers
DNS_SERVERS=(
  "2.180.2.199"
  "2.176.195.122"
  "2.190.110.158"
  "2.190.62.95"
  "2.185.148.251"
  "2.184.172.143"
  "2.186.127.90"
  "2.185.225.151"
  "10.15.176.138"
  "10.114.143.234"
  "10.139.177.16"
  "10.114.143.234"
  "10.86.93.178"
  "10.86.109.18"
  "10.75.72.19"
  "10.2.36.164"
  "10.30.227.30"
  "10.201.17.99"
  "10.139.177.37"
  "10.88.77.146"
  "1.1.1.1"
  "8.8.8.8"
  "9.9.9.9"
  "217.218.155.155"
  "217.218.127.127"
  "178.22.122.100"
  "185.51.200.2"
  "78.157.42.100"
  "78.157.42.101"
  "10.202.10.10"
  "10.202.10.11"
  "5.202.100.100"
  "5.202.100.101"
  "91.239.100.100"
  "2.189.44.44"
  "81.91.144.116"
  "2.188.21.130"
  "46.245.89.51"
  "91.245.229.1"
  "91.245.229.2"
  "194.60.210.66"
  "87.107.110.108"
  "194.225.62.80"
  "2.185.239.139"
  "37.32.5.60"
  "85.185.157.2"
  "85.185.6.3"
  "185.55.225.25"
  "185.55.226.26"
  "37.156.29.27"
  "185.55.224.24"
  "80.191.209.105"
  "185.51.200.50"
  "37.156.145.21"
  "185.113.59.253"
  "185.187.84.15"
  "194.225.73.141"
  "80.191.40.41"
  "37.156.145.229"
  "185.97.117.187"
  "91.99.101.12"
  "213.176.123.5"
  "46.224.1.42"
  "185.231.182.126"
  "185.51.200.10"
  "185.161.112.34"
  "185.161.112.33"
)

TEST_DOMAIN="google.com"          # Change to any site you like (e.g. "cloudflare.com", "speedtest.net")
TIMEOUT_SEC=1                     # Max wait per query (important!)
TRIES=1                           # Queries per server → average for better accuracy

echo "Testing DNS resolvers from your network..."
echo "Test domain: $TEST_DOMAIN | Timeout: ${TIMEOUT_SEC}s | Tries: $TRIES"
echo "-------------------------------------------------------------"
printf "%-18s %-12s %-10s %s\n" "IP" "Avg Time (ms)" "Success%" "Status"
echo "-------------------------------------------------------------"

for ip in "${DNS_SERVERS[@]}"; do
  total_time=0
  success=0

  for ((i=1; i<=TRIES; i++)); do
    output=$(timeout ${TIMEOUT_SEC} dig +nocmd +noall +notcp +stats +time=3 @$ip $TEST_DOMAIN 2>/dev/null)
    query_time=$(echo "$output" | grep -oP 'Query time: \K\d+' || echo "")

    if [[ -n "$query_time" ]]; then
      total_time=$((total_time + query_time))
      success=$((success + 1))
    fi
  done

  if [[ $success -gt 0 ]]; then
    avg=$((total_time / success))
    success_pct=$((success * 100 / TRIES))
    status="OK"
    color="\e[32m"  # green
  else
    avg="---"
    success_pct=0
    status="FAIL / TIMEOUT"
    color="\e[31m"  # red
  fi

  printf "${color}%-18s %-12s %-10s %s\e[0m\n" "$ip" "$avg" "${success_pct}%" "$status"
done | sort -k2 -n

echo "-------------------------------------------------------------"
