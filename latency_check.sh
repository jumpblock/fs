#!/usr/bin/env bash
set -u

target="${1:-https://clob.polymarket.com/time}"
count="${2:-20}"
interval="${3:-1}"

if [[ -z "$target" ]]; then
  echo "usage: $0 <url-or-hostname> [count] [interval_seconds]" >&2
  echo "example: $0 https://clob.polymarket.com/time 20 1" >&2
  exit 2
fi

if [[ "$target" != http://* && "$target" != https://* ]]; then
  target="https://${target}/"
fi

echo "target=${target} count=${count} interval=${interval}s"

for ((i = 1; i <= count; i++)); do
  curl -sS -o /dev/null \
    --connect-timeout 8 \
    --max-time 15 \
    -w "${i}|%{remote_ip}|%{http_code}|%{time_namelookup}|%{time_connect}|%{time_appconnect}|%{time_starttransfer}|%{time_total}\n" \
    "$target" |
    awk -F'|' '{ ip = ($2 == "" ? "-" : $2); printf "%d ip=%s code=%s dns_ms=%.1f connect_ms=%.1f tls_ms=%.1f ttfb_ms=%.1f total_ms=%.1f\n", $1, ip, $3, $4 * 1000, $5 * 1000, $6 * 1000, $7 * 1000, $8 * 1000 }'

  if [[ "$i" -lt "$count" ]]; then
    sleep "$interval"
  fi
done

# Interpreting Results
# dns_ms: DNS resolution time in milliseconds.
# connect_ms: TCP connection setup time in milliseconds.
# tls_ms: time until TLS handshake completes in milliseconds. For HTTP URLs this can be zero.
# ttfb_ms: time to first byte in milliseconds; this is the most useful single indicator for API responsiveness.
# total_ms: full request time in milliseconds.
# Guidance for latency-sensitive APIs:

# < 50 ms total: excellent.
# 50-150 ms total: good.
# 150-300 ms total: usable but not ideal for latency-sensitive trading.
# > 300 ms total: slow for execution-sensitive workflows; check routing, Cloudflare/geoblock behavior, or VPS location.
# When a domain is behind Cloudflare or another CDN, note that DNS and ping often measure the edge node, not the origin service. Prefer HTTPS timings and real authenticated endpoint timings when available.
