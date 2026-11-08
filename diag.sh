#!/usr/bin/env bash
# diag.sh — first-line Linux diagnostics in one ticket-ready report.
# Usage: ./diag.sh [--offline] [-h]      Save it:  ./diag.sh > report.txt
# Exit code: 0 = no failures, 1 = at least one check failed, 2 = bad option.

set -u
export LC_ALL=C

OFFLINE=0
PUBLIC_HOST="1.1.1.1"      # pinged to test "is the internet reachable"
DNS_NAME="example.com"     # looked up to test DNS
DISK_WARN=90               # warn when a filesystem is at least this % full

for arg in "$@"; do
  case "$arg" in
    --offline) OFFLINE=1 ;;
    -h|--help) sed -n '2,4s/^# //p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# Colours only when printing to a terminal, so saved reports stay plain text.
if [ -t 1 ]; then G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' N=$'\e[0m'; else G="" Y="" R="" N=""; fi
OK=0 WARN=0 FAIL=0

section() {
  echo ""
  echo "=== $1 ==="
}
ok()   { echo "[ ${G}OK${N} ] $*"; OK=$((OK + 1)); }
warn() { echo "[${Y}WARN${N}] $*"; WARN=$((WARN + 1)); }
fail() { echo "[${R}FAIL${N}] $*"; FAIL=$((FAIL + 1)); }
has()  { command -v "$1" >/dev/null 2>&1; }

echo "Diagnostics report — $(date '+%Y-%m-%d %H:%M') — user: $(id -un) — host: $(hostname)"

section "System Information"
echo "Hostname: $(hostname)"
grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"'
echo "Kernel: $(uname -r)"
uptime -p
echo "Load: $(cut -d' ' -f1-3 /proc/loadavg) (1, 5, 15 min)"

section "Disk"
SKIP_FS=(-x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs)
df -h "${SKIP_FS[@]}"
full=0
# df -P prints one line per filesystem: column 5 is "Use%", column 6 the mount point.
while read -r use mount; do
  if [ "${use%\%}" -ge "$DISK_WARN" ]; then warn "$mount is $use full"; full=1; fi
done < <(df -P "${SKIP_FS[@]}" | awk 'NR > 1 {print $5, $6}')
[ "$full" -eq 0 ] && ok "all filesystems are below ${DISK_WARN}% full"

section "Memory"
free -h
avail_pct=$(awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2} END {printf "%d", a * 100 / t}' /proc/meminfo)
if [ "$avail_pct" -lt 10 ]; then warn "only ${avail_pct}% of memory is available"; else ok "${avail_pct}% of memory is available"; fi

section "Network"
ip -brief addr
GW=$(ip route | awk '/^default/ {print $3; exit}')
if [ -z "$GW" ]; then
  fail "no default gateway (not connected, or the network is misconfigured)"
else
  echo "Gateway: $GW"
  # "dynamic" on an IPv4 address means it was assigned by DHCP.
  if ip -4 addr show | grep -q dynamic; then echo "IPv4 address source: DHCP"; else echo "IPv4 address source: static"; fi
  if ping -c 1 -W 2 "$GW" >/dev/null 2>&1; then ok "gateway $GW answers ping"
  else warn "gateway $GW does not answer ping (some routers block ping)"; fi
fi
if [ "$OFFLINE" -eq 1 ]; then
  echo "(--offline: DNS and internet checks skipped)"
else
  # dig asks the DNS server directly; getent may be answered from a local cache, so it's only the fallback.
  if has dig; then dns=$(dig +short +tries=1 +time=3 "$DNS_NAME" 2>/dev/null | grep -v "^;" | head -n 1)
  else dns=$(timeout 5 getent hosts "$DNS_NAME" 2>/dev/null); fi
  if [ -n "$dns" ]; then ok "DNS lookup of $DNS_NAME works"; else fail "DNS lookup of $DNS_NAME failed"; fi
  if ping -c 1 -W 2 "$PUBLIC_HOST" >/dev/null 2>&1; then ok "internet is reachable (ping $PUBLIC_HOST)"
  else fail "cannot reach $PUBLIC_HOST (internet down, or ping blocked)"; fi
fi

section "Users and Permissions"
echo "Logged in:"
who
echo "Current user: $(id)"
# World-writable files can be changed by any user on the machine: a security risk.
ww=$(find "$HOME" -xdev -type f -perm -0002 2>/dev/null | head -n 10)
if [ -n "$ww" ]; then
  warn "world-writable files in your home directory (first 10):"
  echo "$ww"
else
  ok "no world-writable files in your home directory"
fi

section "Services"
if has systemctl && [ -d /run/systemd/system ]; then
  if ! units=$(systemctl --failed --no-legend --plain 2>/dev/null); then
    warn "could not ask systemd for failed services"
  elif [ -n "$units" ]; then
    warn "failed services: $(echo "$units" | awk '{print $1}' | tr '\n' ' ')"
  else
    ok "no failed services"
  fi
else
  echo "systemd is not running — skipped"
fi

section "Printing"
if has lpstat; then
  if lpstat -r 2>/dev/null | grep -q "is running"; then
    ok "print service (CUPS) is running"
    queued=$(lpstat -o 2>/dev/null | wc -l)
    if [ "$queued" -gt 0 ]; then warn "$queued job(s) waiting in the print queue"; else ok "print queue is empty"; fi
  else
    warn "print service (CUPS) is not running"
  fi
else
  echo "CUPS is not installed — skipped"
fi

section "Summary"
echo "$OK OK, $WARN warning(s), $FAIL failure(s)"
echo ""
echo "Ticket notes (fill in before sending):"
echo "  Summary:     <the problem in one sentence>"
echo "  Steps taken: ran diag.sh; <what else you tried>"
echo "  Result:      <solved / escalated to ...>"

[ "$FAIL" -eq 0 ]
