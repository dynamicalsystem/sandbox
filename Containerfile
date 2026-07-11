# Rootless-Podman sandbox for Claude Code.
# Same Containerfile works under `podman build` on macOS (applehv) and
# Windows/WSL2. Built on the Node image because Claude Code is an npm CLI;
# Debian base gives us apt for the iptables/ipset egress firewall.

FROM node:22-bookworm-slim

# iptables        -> egress allowlist firewall (plain per-IP rules; the
#                    podman-machine kernel has no ipset/xt_set module)
# dnsutils (dig)  -> resolve allowlist domains to IPs at startup
# git/curl/ca-certs -> normal agent needs
# ripgrep/fd-find -> search/file-finder tools used by Kimi Code (and useful for
#                    Claude Code); pre-install so agents don't try to bootstrap
#                    them over the network and hit the allowlist.
RUN apt-get update && apt-get install -y --no-install-recommends \
        iptables \
        dnsutils \
        ca-certificates \
        curl \
        git \
        ripgrep \
        fd-find \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# Pinned, not floating. Unpinned, every `cs rebuild` silently jumps to npm's
# latest -- 2.1.207 turned on mouse tracking that Terminal.app can't override,
# which breaks native text selection (Terminal.app has no modifier bypass). Pin
# to the version the host runs and drags fine on. Bump deliberately, not by
# accident; test selection in Terminal.app before moving it.
RUN npm install -g @anthropic-ai/claude-code@2.1.206

# Kimi Code CLI -- installed alongside Claude so the same sandbox image can run
# either agent. Pinned to avoid silent upgrades on rebuild.
RUN npm install -g @moonshot-ai/kimi-code@0.23.5

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# GitHub CLI -> `gh` for PRs, and `gh auth setup-git` wires git's HTTPS
# credential helper to GH_TOKEN so `git push` authenticates without ssh keys.
# Installed from GitHub's apt repo so the arch (arm64 on macOS, amd64 on WSL2)
# is resolved automatically. Build-time fetch of cli.github.com is fine -- the
# egress allowlist only applies at *run* time, not during the image build.
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

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
#
# Claude Code refuses --dangerously-skip-permissions as root unless told it is
# sandboxed. This container genuinely is the sandbox, so declare it. The flag
# is source-confirmed but undocumented -- revisit if a future Claude version
# changes the check (alternative: non-root user + keep-id + sudo firewall).
ENV IS_SANDBOX=1

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]
