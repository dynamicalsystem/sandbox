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

# Optional host-side env file (untracked): a GitHub token for pushing, plus any
# git-identity overrides. It is *sourced*, so it can also mint a token on the
# fly -- e.g. GH_TOKEN=$(gh-app-installation-token ...) -- with the secret that
# mints it (an App private key) never leaving the host.
SANDBOX_ENV="${CLAUDE_SANDBOX_ENV:-$HOME/.config/dynamicalsystem/sandbox}"
if [ -f "$SANDBOX_ENV" ]; then
    set -a; . "$SANDBOX_ENV"; set +a
fi

# Git identity: fall back to the host's git config so commits made inside the
# sandbox carry your name/email with no extra setup. (git reads these env vars
# directly, so no .gitconfig needs to be mounted.)
: "${GIT_AUTHOR_NAME:=$(git config --get user.name 2>/dev/null || true)}"
: "${GIT_AUTHOR_EMAIL:=$(git config --get user.email 2>/dev/null || true)}"
: "${GIT_COMMITTER_NAME:=${GIT_AUTHOR_NAME}}"
: "${GIT_COMMITTER_EMAIL:=${GIT_AUTHOR_EMAIL}}"

# Forward only the variables that are actually set -- an empty value is skipped
# so we never clobber an in-container default (or hand git a blank author).
ENV_ARGS=()
for _v in ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN GH_TOKEN GITHUB_TOKEN \
          GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL \
          CLAUDE_SANDBOX_FIREWALL; do
    [ -n "${!_v:-}" ] && ENV_ARGS+=(-e "$_v")
done

exec "$ENGINE" run --rm -it \
    --cap-add=NET_ADMIN \
    --hostname claude-sandbox \
    -v "$PROJECT_DIR:/work" \
    -v "$CONFIG_VOLUME:/root/.claude" \
    "${ALLOW_MOUNT[@]}" \
    "${PROJECT_MOUNT[@]}" \
    "${ENV_ARGS[@]}" \
    -w /work \
    "$IMAGE" "${CMD[@]}"
