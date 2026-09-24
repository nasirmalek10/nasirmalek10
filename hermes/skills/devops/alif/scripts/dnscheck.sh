#!/usr/bin/env bash
# dnscheck.sh: compare how DNS resolvers answer a name, and whether each one
# validates DNSSEC. Read-only: it only sends DNS queries.
#
# Usage:   dnscheck.sh <DOMAIN> [RESOLVER_IP ...]
# Example: dnscheck.sh example.com <PIHOLE_IP> <OPNSENSE_IP> 1.1.1.1
#
# With no resolvers given, it uses the nameservers in /etc/resolv.conf plus
# 1.1.1.1 and 9.9.9.9 for comparison.
#
# Reading the results:
#   answer 0.0.0.0 / ::                    blocked by a filtering resolver (e.g. Pi-hole)
#   SERVFAIL, but NOERROR with +cd         DNSSEC validation failure
#   DNSSEC test = validating               resolver rejects the deliberately broken dnssec-failed.org
#   "ad" in flags                           resolver validated the answer with DNSSEC

set -uo pipefail

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
}

if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  exit 1
fi

if ! command -v dig >/dev/null 2>&1; then
  echo "dig is required. Install it with one of:" >&2
  echo "  Debian/Ubuntu: sudo apt install bind9-dnsutils   (older releases: dnsutils)" >&2
  echo "  Fedora/RHEL:   sudo dnf install bind-utils" >&2
  echo "  Alpine:        sudo apk add bind-tools" >&2
  exit 2
fi

DOMAIN="$1"
shift

RESOLVERS=()
if [ $# -gt 0 ]; then
  RESOLVERS=("$@")
else
  if [ -r /etc/resolv.conf ]; then
    while read -r ns; do
      RESOLVERS+=("$ns")
    done < <(awk '/^[[:space:]]*nameserver[[:space:]]/ {print $2}' /etc/resolv.conf)
  fi
  RESOLVERS+=(1.1.1.1 9.9.9.9)
fi

# query RESOLVER NAME TYPE [extra dig options...]
query() {
  local resolver="$1" name="$2" type="$3"
  shift 3
  dig +time=2 +tries=1 +noall +comments +answer +stats "$@" "@$resolver" "$name" "$type" 2>&1
}
status_of() { sed -n 's/.*status: \([A-Z]*\).*/\1/p' | head -n 1; }
flags_of() { sed -n 's/^;; flags: \([^;]*\);.*/\1/p' | head -n 1; }
time_of() { sed -n 's/^;; Query time: \([0-9]*\) msec.*/\1 ms/p' | head -n 1; }
answers_of() {
  awk -v t="$1" '!/^;/ && NF >= 5 && $4 == t { printf "%s ", $5; n++ } END { if (!n) printf "(none)" }'
}

printf 'DNS check for %s  (%s)\n' "$DOMAIN" "$(date -Is)"

for r in "${RESOLVERS[@]}"; do
  printf '\n=== Resolver %s ===\n' "$r"

  out_a="$(query "$r" "$DOMAIN" A)"
  status="$(status_of <<<"$out_a")"
  if [ -z "$status" ]; then
    printf '  A      : no response (%s)\n' "$(grep -m1 -E 'timed out|refused|unreachable|error' <<<"$out_a" || echo 'unknown error')"
    continue
  fi
  printf '  A      : %-9s flags [%s]  %s  -> %s\n' \
    "$status" "$(flags_of <<<"$out_a")" "$(time_of <<<"$out_a")" "$(answers_of A <<<"$out_a")"

  out_aaaa="$(query "$r" "$DOMAIN" AAAA)"
  printf '  AAAA   : %-9s -> %s\n' "$(status_of <<<"$out_aaaa")" "$(answers_of AAAA <<<"$out_aaaa")"

  if grep -Eq '^0\.0\.0\.0 ?$|^:: ?$' <<<"$(answers_of A <<<"$out_a")"; then
    printf '  NOTE   : null answer, so this name is blocked by this resolver\n'
  fi

  if [ "$status" = "SERVFAIL" ]; then
    out_cd="$(query "$r" "$DOMAIN" A +cd)"
    cd_status="$(status_of <<<"$out_cd")"
    if [ "$cd_status" = "NOERROR" ]; then
      printf '  NOTE   : SERVFAIL, but NOERROR with +cd (checking disabled): DNSSEC validation failure\n'
    else
      printf '  NOTE   : still %s with +cd, so not DNSSEC; check upstream reachability and the domain'"'"'s nameservers\n' "${cd_status:-no response}"
    fi
  fi

  out_bad="$(query "$r" dnssec-failed.org A)"
  case "$(status_of <<<"$out_bad")" in
    SERVFAIL) printf '  DNSSEC : validating (rejects dnssec-failed.org)\n' ;;
    NOERROR)  printf '  DNSSEC : NOT validating (accepted dnssec-failed.org)\n' ;;
    NXDOMAIN) printf '  DNSSEC : inconclusive (dnssec-failed.org returned NXDOMAIN, possibly blocked)\n' ;;
    *)        printf '  DNSSEC : inconclusive (no clear answer)\n' ;;
  esac
done

printf '\nDone. If resolvers disagree, the difference points at filtering, split-horizon overrides, or a caching/upstream problem.\n'
