#!/usr/bin/env bash
# Run Claude Code or Kimi Code inside a rootless-Podman sandbox.
#
# Usage:
#   cs                            # claude --dangerously-skip-permissions, in $PWD
#   cs <args...>                  # claude <args...>
#   cs kimi                       # kimi --yolo, in $PWD
#   cs kimi <args...>             # kimi <args...>
#   cs shell                      # interactive bash in the sandbox
#   cs rebuild                    # rebuild the image (after editing scripts / updating)
#   cs --worktree foo             # run in the foo worktree of the current product
#
# The current directory (or the directory named by --worktree) is mounted at
# /work. Egress is limited to the global allowlist plus, if present, the
# project's .claude-sandbox/allowed-domains.txt. Auth (~/.claude and
# ~/.kimi-code) persists in named volumes across runs.
#
# Cross-platform: runs under zsh/bash on macOS and bash in Windows/WSL2.
set -euo pipefail

ENGINE="${CLAUDE_SANDBOX_ENGINE:-podman}"
IMAGE="${CLAUDE_SANDBOX_IMAGE:-claude-sandbox:latest}"
CONFIG_VOLUME="${CLAUDE_SANDBOX_CONFIG_VOLUME:-claude-config}"
KIMI_CONFIG_VOLUME="${CLAUDE_SANDBOX_KIMI_CONFIG_VOLUME:-kimi-config}"
PROJECT_DIR="${CLAUDE_SANDBOX_WORKDIR:-$PWD}"

# Parse an optional --worktree <name> switch before the agent sees the arguments.
WORKTREE_NAME=""
RAW_ARGS=("$@")
set --
_i=0
while [ "$_i" -lt "${#RAW_ARGS[@]}" ]; do
    _arg="${RAW_ARGS[$_i]}"
    if [ "$_arg" = "--worktree" ]; then
        _i=$((_i + 1))
        WORKTREE_NAME="${RAW_ARGS[$_i]:-}"
        if [ -z "$WORKTREE_NAME" ]; then
            echo "error: --worktree requires a name" >&2
            exit 1
        fi
    else
        set -- "$@" "$_arg"
    fi
    _i=$((_i + 1))
done

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
    CONTAINER_HOSTNAME="sandbox"
elif [ "${1:-}" = "kimi" ]; then
    shift
    if [ "$#" -eq 0 ]; then
        CMD=(kimi --yolo)
    else
        CMD=(kimi "$@")
    fi
    CONTAINER_HOSTNAME="kimi-sandbox"
elif [ "$#" -eq 0 ]; then
    CMD=(claude --dangerously-skip-permissions)
    CONTAINER_HOSTNAME="claude-sandbox"
else
    CMD=(claude "$@")
    CONTAINER_HOSTNAME="claude-sandbox"
fi

# Global allowlist: mount the host copy over the baked-in one so edits apply
# without a rebuild.
ALLOW_MOUNT=()
if [ -f "$SANDBOX_DIR/allowed-domains.txt" ]; then
    ALLOW_MOUNT=(-v "$SANDBOX_DIR/allowed-domains.txt:/etc/claude-sandbox/allowed-domains.txt:ro")
fi

# Product-worktree mode: if the launch directory (or an explicitly named
# worktree) is inside a product directory that also has main/ and ooda/
# worktrees, mount the sandbox worktree at /work and also mount main/ and ooda/
# at their host absolute paths so Git metadata resolves and /orient can read the
# control plane. Otherwise fall back to mounting the launch dir at /work.
SANDBOX_WORKTREE="$PROJECT_DIR"
if [ -n "$WORKTREE_NAME" ]; then
    _repo_root="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -z "$_repo_root" ]; then
        echo "error: --worktree requires the launch directory to be inside a Git repo" >&2
        exit 1
    fi
    _product_root="$(dirname "$_repo_root")"
    SANDBOX_WORKTREE="$_product_root/$WORKTREE_NAME"
    if [ ! -d "$SANDBOX_WORKTREE" ]; then
        echo "error: worktree not found: $SANDBOX_WORKTREE" >&2
        exit 1
    fi
fi

OODA_MAIN_DIR=""
OODA_OODA_DIR=""
if [ -d "$SANDBOX_WORKTREE" ]; then
    _repo_root="$(git -C "$SANDBOX_WORKTREE" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$_repo_root" ]; then
        _git_common="$(git -C "$SANDBOX_WORKTREE" rev-parse --git-common-dir 2>/dev/null || true)"
        _main_dir="$(dirname "$_git_common")"
        _product_root="$(dirname "$_main_dir")"
        if [ -d "$_product_root/main" ] && [ -d "$_product_root/ooda" ]; then
            OODA_MAIN_DIR="$_product_root/main"
            OODA_OODA_DIR="$_product_root/ooda"
        fi
    fi
fi

WORK_MOUNT=()
WORK_DIR="/work"
PROJECT_MOUNT=()
if [ -n "$OODA_MAIN_DIR" ] && [ -n "$OODA_OODA_DIR" ]; then
    WORK_MOUNT=(
        -v "$SANDBOX_WORKTREE:/work"
        -v "$OODA_MAIN_DIR:$OODA_MAIN_DIR"
        -v "$OODA_OODA_DIR:$OODA_OODA_DIR"
    )
    if [ -f "$OODA_MAIN_DIR/.claude-sandbox/allowed-domains.txt" ]; then
        PROJECT_MOUNT=(-v "$OODA_MAIN_DIR/.claude-sandbox/allowed-domains.txt:/etc/claude-sandbox/project-domains.txt:ro")
    fi
else
    WORK_MOUNT=(-v "$PROJECT_DIR:/work")
    if [ -f "$PROJECT_DIR/.claude-sandbox/allowed-domains.txt" ]; then
        PROJECT_MOUNT=(-v "$PROJECT_DIR/.claude-sandbox/allowed-domains.txt:/etc/claude-sandbox/project-domains.txt:ro")
    fi
fi

# Host-side Kimi skills / AGENTS.md: share host-managed skills and global prompt
# with the container while keeping auth/config/session state in the named volume.
KIMI_HOST_DIR="${KIMI_HOST_DIR:-$HOME/.kimi-code}"
KIMI_SKILLS_MOUNT=()
if [ -d "$KIMI_HOST_DIR/skills" ]; then
    KIMI_SKILLS_MOUNT=(-v "$KIMI_HOST_DIR/skills:/root/.kimi-code/skills:ro")
fi
KIMI_AGENTS_MOUNT=()
if [ -L "$KIMI_HOST_DIR/AGENTS.md" ] || [ -f "$KIMI_HOST_DIR/AGENTS.md" ]; then
    KIMI_AGENTS_MOUNT=(-v "$KIMI_HOST_DIR/AGENTS.md:/root/.kimi-code/AGENTS.md:ro")
fi

# Optional host-side env file (untracked): a GitHub token for pushing, plus any
# git-identity overrides. It is *sourced*, so it can also mint a token on the
# fly -- e.g. GH_TOKEN=$(gh-app-installation-token ...) -- with the secret that
# mints it (an App private key) never leaving the host.
SANDBOX_ENV="${CLAUDE_SANDBOX_ENV:-$HOME/.config/dynamicalsystem/sandbox}"
# Accept either a plain file or a directory holding an `env` file, so both
# ~/.config/dynamicalsystem/sandbox and ~/.config/dynamicalsystem/sandbox/env
# work without setting CLAUDE_SANDBOX_ENV.
[ -d "$SANDBOX_ENV" ] && [ -f "$SANDBOX_ENV/env" ] && SANDBOX_ENV="$SANDBOX_ENV/env"
if [ -f "$SANDBOX_ENV" ]; then
    set -a; . "$SANDBOX_ENV"; set +a
fi

# Keep Claude from overwriting the terminal title we set below. Default to
# disabling it; set CLAUDE_CODE_DISABLE_TERMINAL_TITLE= (empty) to let Claude
# manage the title instead. Use '=' (not ':=') so an explicit empty value is
# honoured -- ':=' would clobber it back to 1 and break that opt-out.
: "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1}"

# Do NOT force CLAUDE_CODE_DISABLE_MOUSE_CLICKS. On the pinned 2.1.206 the mouse
# is not grabbed by default, so Terminal.app native text selection works -- same
# as the host. Forcing =1 put 2.1.206 into scroll-tracking mode, which
# Terminal.app treats as "app owns the mouse", breaking selection. It is still
# forwarded if you set it yourself in the env file, but left unset by default.

# Git identity: fall back to the host's git config so commits made inside the
# sandbox carry your name/email with no extra setup. (git reads these env vars
# directly, so no .gitconfig needs to be mounted.)
: "${GIT_AUTHOR_NAME:=$(git config --get user.name 2>/dev/null || true)}"
: "${GIT_AUTHOR_EMAIL:=$(git config --get user.email 2>/dev/null || true)}"
: "${GIT_COMMITTER_NAME:=${GIT_AUTHOR_NAME}}"
: "${GIT_COMMITTER_EMAIL:=${GIT_AUTHOR_EMAIL}}"

# Forward only the variables that are actually set -- an empty value is skipped
# so we never clobber an in-container default (or hand git a blank author).
# Pass the value explicitly (-e NAME=VALUE) rather than the bare -e NAME form:
# several of these are plain shell vars set via ":=" above (not exported), so
# the bare form -- which makes podman read from our environment -- would forward
# nothing for them.
ENV_ARGS=()
for _v in ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN GH_TOKEN GITHUB_TOKEN \
          GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL \
          CLAUDE_CODE_DISABLE_TERMINAL_TITLE CLAUDE_CODE_DISABLE_MOUSE_CLICKS \
          KIMI_API_KEY KIMI_BASE_URL KIMI_MODEL KIMI_MAX_TOKENS \
          CLAUDE_SANDBOX_FIREWALL; do
    [ -n "${!_v:-}" ] && ENV_ARGS+=(-e "$_v=${!_v}")
done

# Set the host terminal's title to the project's git repo name, falling back to
# the launch directory's name when it isn't a repo, so the tab/window is
# identifiable while Claude runs. Done here in the launcher (not just the cs.zsh
# wrapper) so it works no matter how `cs` is invoked, and Claude won't clobber it
# (CLAUDE_CODE_DISABLE_TERMINAL_TITLE is set above). Best-effort: only when
# stdout is a tty, so piping/redirecting cs stays clean.
if [ -t 1 ]; then
    TITLE="$(git -C "$SANDBOX_WORKTREE" rev-parse --show-toplevel 2>/dev/null || true)"
    TITLE="${TITLE##*/}"
    [ -n "$TITLE" ] || TITLE="${SANDBOX_WORKTREE##*/}"
    printf '\033]0;%s\007' "$TITLE"
fi

exec "$ENGINE" run --rm -it \
    --cap-add=NET_ADMIN \
    --hostname "$CONTAINER_HOSTNAME" \
    "${WORK_MOUNT[@]}" \
    -v "$CONFIG_VOLUME:/root/.claude" \
    -v "$KIMI_CONFIG_VOLUME:/root/.kimi-code" \
    "${KIMI_SKILLS_MOUNT[@]}" \
    "${KIMI_AGENTS_MOUNT[@]}" \
    "${ALLOW_MOUNT[@]}" \
    "${PROJECT_MOUNT[@]}" \
    "${ENV_ARGS[@]}" \
    -w "$WORK_DIR" \
    "$IMAGE" "${CMD[@]}"
