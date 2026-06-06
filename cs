#!/usr/bin/env bash
# Run Claude Code inside a rootless-Podman sandbox.
#
# Usage:
#   cs                  # claude --dangerously-skip-permissions, in $PWD
#   cs <args...>        # claude <args...>
#   cs shell            # interactive bash in the sandbox
#   cs rebuild          # rebuild the image (after editing scripts / updating)
#
# The current directory is mounted at /work; nothing else of your host is
# visible. Egress is limited to the global allowlist plus, if present, the
# launch dir's .claude-sandbox/allowed-domains.txt. Auth (~/.claude) persists
# in a named volume across runs.
#
# Cross-platform: runs under zsh/bash on macOS and bash in Windows/WSL2.
set -euo pipefail

ENGINE="${CLAUDE_SANDBOX_ENGINE:-podman}"
IMAGE="${CLAUDE_SANDBOX_IMAGE:-claude-sandbox:latest}"
CONFIG_VOLUME="${CLAUDE_SANDBOX_CONFIG_VOLUME:-claude-config}"
PROJECT_DIR="${CLAUDE_SANDBOX_WORKDIR:-$PWD}"

# Resolve this script's real location, following symlinks, so the image and
# global allowlist are found even when invoked as ~/.local/bin/cs.
SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [ "${SOURCE#/}" = "$SOURCE" ] && SOURCE="$DIR/$SOURCE"
done
SANDBOX_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

if ! command -v "$ENGINE" >/dev/null 2>&1; then
    echo "error: '$ENGINE' not found on PATH" >&2
    exit 1
fi

# Force a rebuild (after editing baked scripts or pulling an update).
if [ "${1:-}" = "rebuild" ]; then
    echo "[sandbox] rebuilding $IMAGE ..." >&2
    exec "$ENGINE" build --no-cache -t "$IMAGE" "$SANDBOX_DIR"
fi

# Build on first use (or after you edit the Containerfile).
if ! "$ENGINE" image exists "$IMAGE" 2>/dev/null; then
    echo "[sandbox] building $IMAGE (first run) ..." >&2
    "$ENGINE" build -t "$IMAGE" "$SANDBOX_DIR"
fi

# What to run inside.
if [ "${1:-}" = "shell" ]; then
    shift
    CMD=(bash "$@")
elif [ "$#" -eq 0 ]; then
    CMD=(claude --dangerously-skip-permissions)
else
    CMD=(claude "$@")
fi

# Global allowlist: mount the host copy over the baked-in one so edits apply
# without a rebuild.
ALLOW_MOUNT=()
if [ -f "$SANDBOX_DIR/allowed-domains.txt" ]; then
    ALLOW_MOUNT=(-v "$SANDBOX_DIR/allowed-domains.txt:/etc/claude-sandbox/allowed-domains.txt:ro")
fi

# Per-project allowlist: merged in by the firewall if the launch dir has one.
PROJECT_MOUNT=()
if [ -f "$PROJECT_DIR/.claude-sandbox/allowed-domains.txt" ]; then
    PROJECT_MOUNT=(-v "$PROJECT_DIR/.claude-sandbox/allowed-domains.txt:/etc/claude-sandbox/project-domains.txt:ro")
fi

exec "$ENGINE" run --rm -it \
    --cap-add=NET_ADMIN \
    --hostname claude-sandbox \
    -v "$PROJECT_DIR:/work" \
    -v "$CONFIG_VOLUME:/root/.claude" \
    "${ALLOW_MOUNT[@]}" \
    "${PROJECT_MOUNT[@]}" \
    -e ANTHROPIC_API_KEY \
    -e CLAUDE_SANDBOX_FIREWALL \
    -w /work \
    "$IMAGE" "${CMD[@]}"
