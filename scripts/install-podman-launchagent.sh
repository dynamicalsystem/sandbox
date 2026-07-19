#!/usr/bin/env bash
# Install a macOS LaunchAgent that starts the default Podman machine at login.
#
# This script is invoked by install.sh on macOS unless SANDBOX_SKIP_PODMAN_LAUNCHAGENT=1.
# It is a no-op on other operating systems.
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
    exit 0
fi

if ! command -v podman >/dev/null 2>&1; then
    echo "[podman-launchagent] WARNING: podman not found. Install it, then run 'podman machine init && podman machine start'." >&2
    exit 0
fi

start_machine_if_needed() {
    local default_machine
    default_machine=$(podman machine list --format '{{.Name}}' | head -n1 | sed 's/\*$//')
    if [ -z "$default_machine" ]; then
        echo "[podman-launchagent] WARNING: no podman machine found. Run 'podman machine init && podman machine start' to create one." >&2
        return 0
    fi

    local machine_state
    machine_state=$(podman machine inspect "$default_machine" --format '{{.State}}' 2>/dev/null || echo "unknown")
    if [ "$machine_state" = "running" ]; then
        echo "[podman-launchagent] machine $default_machine is already running"
        return 0
    fi

    echo "[podman-launchagent] starting podman machine $default_machine"
    podman machine start
}

# When invoked by launchd, just ensure the machine is running.
if [ "${1:-}" = "--agent" ]; then
    start_machine_if_needed
    exit 0
fi

# Installer mode: write and load the LaunchAgent, then start the machine now.
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs"
PLIST_NAME="com.podman.machine.start.plist"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

mkdir -p "$LAUNCH_AGENTS_DIR" "$LOG_DIR"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.podman.machine.start</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_PATH</string>
        <string>--agent</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/podman-machine-start.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/podman-machine-start.log</string>
</dict>
</plist>
EOF

echo "[podman-launchagent] wrote $PLIST_PATH"

# Idempotently load the agent.
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "[podman-launchagent] loaded $PLIST_NAME"

start_machine_if_needed
