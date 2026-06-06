#!/usr/bin/env bash
# Apply the egress firewall (unless disabled), then hand off to whatever
# command the wrapper asked for (claude / bash / ...).
set -euo pipefail

# Anthropic auth is forwarded statelessly via CLAUDE_CODE_OAUTH_TOKEN (see `cs`
# and the README), exactly like GH_TOKEN below -- nothing to persist in the
# volume, nothing to re-auth. We deliberately do NOT symlink /root/.claude.json
# into the volume: Claude Code writes that file atomically (write-temp +
# rename()), and rename() replaces the symlink with a real file in the ephemeral
# overlay instead of writing through it, so the symlink never actually persisted
# and the OAuth account record was dropped on every --rm.

if [ "${CLAUDE_SANDBOX_FIREWALL:-1}" = "1" ]; then
    if /usr/local/bin/init-firewall.sh; then
        :
    else
        echo "[sandbox] WARNING: firewall failed to apply -- egress is NOT restricted" >&2
        echo "[sandbox]          set CLAUDE_SANDBOX_FIREWALL=0 to silence, or investigate." >&2
    fi
else
    echo "[sandbox] firewall disabled (CLAUDE_SANDBOX_FIREWALL=0) -- egress is open" >&2
fi

# If a GitHub token was forwarded in, point git's HTTPS credential helper at it
# (gh reads GH_TOKEN / GITHUB_TOKEN automatically) so `git push` and `gh` work
# over 443 -- no ssh key in the sandbox. Harmless no-op when no token is set.
if [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then
    gh auth setup-git >/dev/null 2>&1 \
        || echo "[sandbox] WARNING: 'gh auth setup-git' failed -- git push over HTTPS may not authenticate" >&2
fi

exec "$@"
