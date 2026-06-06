#!/usr/bin/env bash
# Default-deny egress firewall. Allows all outbound HTTP/HTTPS and DNS so
# Claude can reach any website or API endpoint mid-session without restarts.
# Everything else (raw TCP to non-web ports, etc.) is dropped.
set -euo pipefail

if ! iptables -L >/dev/null 2>&1; then
    echo "iptables unusable -- did you pass --cap-add=NET_ADMIN ?" >&2
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

# DNS.
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# All outbound HTTP and HTTPS.
iptables -A OUTPUT -p tcp --dport 80  -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

echo "[firewall] active: all outbound HTTP/HTTPS allowed, other ports blocked"
