#!/usr/bin/env bash
# Default-deny egress firewall. Resolves the allowlist domains to IPs and
# drops everything else outbound. Runs inside the container's own network
# namespace, so under rootless podman it needs only --cap-add=NET_ADMIN,
# not host root.
#
# Uses plain per-IP iptables rules (no ipset) -- the podman-machine kernel
# does not ship the ipset/xt_set module, but core iptables works fine.
set -euo pipefail

# Global list plus an optional per-project list (mounted by the wrapper when
# the launch dir has .claude-sandbox/allowed-domains.txt).
ALLOW_FILES="${CLAUDE_SANDBOX_ALLOWLIST:-/etc/claude-sandbox/allowed-domains.txt} /etc/claude-sandbox/project-domains.txt"

if ! iptables -L >/dev/null 2>&1; then
    echo "iptables unusable -- did you pass --cap-add=NET_ADMIN ?" >&2
    exit 1
fi

# Resolve the allowlist(s) FIRST, while DNS still works (before we lock down).
ips=""
domains=0
for allow_file in $ALLOW_FILES; do
    [ -f "$allow_file" ] || continue
    while IFS= read -r raw; do
        domain="${raw%%#*}"                       # strip comments
        domain="$(echo "$domain" | tr -d '[:space:]')"
        [ -z "$domain" ] && continue
        domains=$((domains + 1))
        for ip in $(dig +short A "$domain" | grep -E '^[0-9.]+$'); do
            ips="$ips $ip"
        done
    done < "$allow_file"
done

ips="$(echo "$ips" | tr ' ' '\n' | grep -E '^[0-9.]+$' | sort -u)"

if [ -z "$ips" ]; then
    echo "no domains resolved from $ALLOW_FILES -- refusing to lock down with an empty allowlist" >&2
    exit 1
fi

# Default-deny.
iptables -F OUTPUT
iptables -F INPUT
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  DROP

# Loopback.
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Let replies to our own outbound connections back in.
iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# DNS (needed to resolve allowed hosts during the session).
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# The allowlist itself -- one ACCEPT per resolved address.
count=0
for ip in $ips; do
    iptables -A OUTPUT -d "$ip" -j ACCEPT
    count=$((count + 1))
done

echo "[firewall] allowlist active: $count address(es) from $domains domain(s)"
