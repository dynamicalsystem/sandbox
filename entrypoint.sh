#!/usr/bin/env bash
# Apply the egress firewall (unless disabled), then hand off to whatever
# command the wrapper asked for (claude / bash / ...).
set -euo pipefail

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

exec "$@"
