# Rootless-Podman sandbox for Claude Code.
# Same Containerfile works under `podman build` on macOS (applehv) and
# Windows/WSL2. Built on the Node image because Claude Code is an npm CLI;
# Debian base gives us apt for the iptables/ipset egress firewall.

FROM node:22-bookworm-slim

# iptables        -> egress allowlist firewall (plain per-IP rules; the
#                    podman-machine kernel has no ipset/xt_set module)
# dnsutils (dig)  -> resolve allowlist domains to IPs at startup
# git/curl/ca-certs -> normal agent needs
RUN apt-get update && apt-get install -y --no-install-recommends \
        iptables \
        dnsutils \
        ca-certificates \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Default egress allowlist. The wrapper can mount a host copy over this
# path, so edits on the host take effect without a rebuild.
RUN mkdir -p /etc/claude-sandbox
COPY allowed-domains.txt /etc/claude-sandbox/allowed-domains.txt

COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY entrypoint.sh    /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh

# We deliberately stay as root *inside* the container. Under rootless
# podman that maps to your unprivileged host user, so:
#   - iptables can program the firewall (NET_ADMIN within the userns)
#   - files written to the /work bind mount come out owned by you on the host
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]
