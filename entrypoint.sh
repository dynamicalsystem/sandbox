#!/usr/bin/env bash
# Apply the egress firewall (unless disabled), then hand off to whatever
# command the wrapper asked for (claude / bash / ...).
set -euo pipefail

# Anthropic auth is forwarded statelessly via CLAUDE_CODE_OAUTH_TOKEN (see `cs`
# and the README), exactly like GH_TOKEN below -- nothing auth-related needs to
# persist in the volume. But auth is not the whole story: Claude Code also gates
# its interactive first-run flow (the browser login) on ~/.claude.json, which
# holds hasCompletedOnboarding + the account record. That file lives at $HOME,
# OUTSIDE the /root/.claude volume, so --rm wipes it and every interactive launch
# reruns onboarding and drops to the browser even though the token already
# authenticates (headless `claude -p` just warns and proceeds -- the TUI blocks).
#
# We do NOT symlink it into the volume: Claude writes it atomically (write-temp +
# rename()), and rename() replaces a symlink with a real file in the ephemeral
# overlay instead of writing through it, so it never persisted. Instead we seed
# it before handoff.
#
# Seed ONLY the onboarding flag -- deliberately NOT a stored oauthAccount record.
# Asserting "logged in as <account>" when the matching credential in the volume
# (/root/.claude/.credentials.json) has expired makes the interactive TUI 401
# ("please run /login") instead of using the forwarded token or prompting a fresh
# login. So we claim onboarding-done and nothing else; auth is left entirely to
# CLAUDE_CODE_OAUTH_TOKEN (reliable headless; per docs also the TUI, though
# interactive token support is flaky upstream -- see anthropics/claude-code#69753)
# or a real /login whose .credentials.json persists in the volume on its own.
[ -e /root/.claude.json ] || printf '{"hasCompletedOnboarding":true}\n' > /root/.claude.json

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
