#!/usr/bin/env bash
# Apply the egress firewall (unless disabled), then hand off to whatever
# command the wrapper asked for (claude / bash / ...).
set -euo pipefail

# Persist ~/.claude.json across runs. Claude Code keeps OAuth *credentials* in
# /root/.claude/ (the named config volume, so those already survive), but the
# OAuth account + onboarding state lives in /root/.claude.json, which sits
# OUTSIDE that volume and is otherwise wiped on every --rm -- the cause of
# re-auth on each launch. Symlink it into the volume so auth fully persists.
ln -sf /root/.claude/.claude.json /root/.claude.json

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
