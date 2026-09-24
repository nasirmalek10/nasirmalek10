#!/usr/bin/env bash
# netdiag.sh: read-only network snapshot of a Linux host.
#
# Usage:   netdiag.sh [TARGET_HOST]      (default: example.com)
# Example: sudo ./netdiag.sh github.com | tee netdiag.txt
#
# Makes NO configuration changes. Run with sudo to include firewall rules and
# process names on listening sockets; without it those sections are partial.
# Tools that are not installed are skipped.

set -uo pipefail

TARGET="${1:-example.com}"
TIMEOUT=5

have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n===== %s =====\n' "$1"; }
run() {
  printf '$ %s\n' "$*"
  timeout "$TIMEOUT" "$@" 2>&1 || printf '(exit %s)\n' "$?"
}
run_long() {
  printf '$ %s\n' "$*"
  timeout 60 "$@" 2>&1 || printf '(exit %s)\n' "$?"
}
skip() { printf '(skipped: %s not installed)\n' "$1"; }

section "Host"
printf 'Date:     %s\n' "$(date -Is)"
printf 'Hostname: %s\n' "$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null)"
printf 'Kernel:   %s\n' "$(uname -r)"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  printf 'OS:       %s\n' "$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-unknown}")"
fi
printf 'User:     %s (uid %s)\n' "$(id -un)" "$(id -u)"
if have timedatectl; then run timedatectl; fi

section "Interfaces"
if have ip; then
  run ip -br link
  run ip -br addr
else
  skip ip
fi

section "Routes"
GATEWAY=""
if have ip; then
  run ip route
  run ip -6 route
  GATEWAY="$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')"
  printf 'Default IPv4 gateway: %s\n' "${GATEWAY:-none}"
else
  skip ip
fi

section "Gateway reachability"
if [ -n "$GATEWAY" ] && have ping; then
  run_long ping -c 3 -W 2 "$GATEWAY"
else
  printf '(skipped: no default gateway or ping not installed)\n'
fi

section "DNS configuration"
run ls -l /etc/resolv.conf
if [ -r /etc/resolv.conf ]; then
  grep -Ev '^[[:space:]]*(#|$)' /etc/resolv.conf
fi
if have resolvectl; then run resolvectl status; fi

section "Name resolution: $TARGET"
if have getent; then run getent ahosts "$TARGET"; else skip getent; fi
if have dig; then
  run dig +time=2 +tries=1 "$TARGET"
  if [ -r /etc/resolv.conf ]; then
    awk '/^[[:space:]]*nameserver[[:space:]]/ {print $2}' /etc/resolv.conf |
      while read -r ns; do
        printf -- '--- via %s: ' "$ns"
        timeout "$TIMEOUT" dig +short +time=2 +tries=1 "@$ns" "$TARGET" 2>&1 | tr '\n' ' '
        printf '\n'
      done
  fi
else
  skip dig
fi

section "Internet reachability"
if have ping; then
  run_long ping -c 3 -W 2 1.1.1.1
else
  skip ping
fi
if have curl; then
  printf '$ curl https://%s\n' "$TARGET"
  curl -sS -o /dev/null --max-time 10 \
    -w 'HTTP %{http_code}  remote %{remote_ip}  dns %{time_namelookup}s  connect %{time_connect}s  tls %{time_appconnect}s  total %{time_total}s\n' \
    "https://$TARGET" 2>&1 || printf '(exit %s)\n' "$?"
else
  skip curl
fi

section "Path to $TARGET"
if have tracepath; then
  run_long tracepath -n -m 15 "$TARGET"
elif have traceroute; then
  run_long traceroute -n -m 15 -w 2 "$TARGET"
else
  printf '(skipped: neither tracepath nor traceroute installed)\n'
fi

section "Listening sockets"
if have ss; then
  run ss -tulpn
elif have netstat; then
  run netstat -tulpn
else
  printf '(skipped: neither ss nor netstat installed)\n'
fi

section "Firewall"
if [ "$(id -u)" -ne 0 ]; then
  printf '(not root: firewall details need sudo)\n'
fi
if have nft; then
  printf '$ nft list ruleset (first 200 lines)\n'
  timeout "$TIMEOUT" nft list ruleset 2>&1 | head -n 200
fi
if have iptables; then
  printf '$ iptables -S (first 100 lines)\n'
  timeout "$TIMEOUT" iptables -S 2>&1 | head -n 100
fi
if have ufw; then run ufw status verbose; fi
if have firewall-cmd; then run firewall-cmd --state; fi

section "Docker networks"
if have docker; then
  run docker network ls
  for net in $(docker network ls -q 2>/dev/null); do
    docker network inspect -f '{{.Name}}: {{range .IPAM.Config}}{{.Subnet}} {{end}}' "$net" 2>/dev/null
  done
else
  skip docker
fi

printf '\nDone. No changes were made.\n'
