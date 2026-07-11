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
# overlay instead of writing through it, so the account record was dropped on
# every --rm. Instead we restore it by plain copy before handoff.
#
# Claude backs this file up (into backups/) before every atomic rewrite, so the
# volume accumulates copies -- but a broken/minimal session leaves a tiny stub,
# so "newest backup" is not safe to trust. Scan the persisted copies newest-first
# and pick the first that actually carries the account record (oauthAccount);
# fall back to a minimal onboarding stub. Auth still comes from the token -- this
# only satisfies the interactive onboarding gate. Once login works again, good
# sessions write full backups, so the restore source stays fresh on its own.
if [ ! -e /root/.claude.json ]; then
    src=""
    for f in $(ls -t /root/.claude/.claude.json /root/.claude/backups/.claude.json.backup.* 2>/dev/null || true); do
        if grep -q '"oauthAccount"' "$f" 2>/dev/null; then src="$f"; break; fi
    done
    if [ -n "$src" ]; then
        cp "$src" /root/.claude.json
    else
        printf '{"hasCompletedOnboarding":true}\n' > /root/.claude.json
    fi
fi

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
