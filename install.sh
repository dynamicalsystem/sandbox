#!/usr/bin/env bash
# Install the `cs` Claude sandbox launcher onto your PATH.
#
#   curl -fsSL https://raw.githubusercontent.com/dynamicalsystem/sandbox/main/install.sh | bash
#
# or, from a local checkout:
#
#   ./install.sh
#
# Env overrides:
#   SANDBOX_HOME   where to clone the repo when curled  (default ~/.local/share/sandbox)
#   SANDBOX_REPO   git URL to clone                      (default the dynamicalsystem repo)
#   PREFIX         bin dir for the `cs` symlink          (default ~/.local/bin)
set -euo pipefail

SANDBOX_REPO="${SANDBOX_REPO:-https://github.com/dynamicalsystem/sandbox.git}"
SANDBOX_HOME="${SANDBOX_HOME:-$HOME/.local/share/sandbox}"
PREFIX="${PREFIX:-$HOME/.local/bin}"

# Are we running from a real checkout, or piped from curl?
SELF="${BASH_SOURCE[0]:-}"
if [ -n "$SELF" ] && [ -f "$(dirname "$SELF")/cs" ] && [ -f "$(dirname "$SELF")/Containerfile" ]; then
    REPO_DIR="$(cd "$(dirname "$SELF")" && pwd)"
    echo "[install] using local checkout: $REPO_DIR"
else
    REPO_DIR="$SANDBOX_HOME"
    if [ -d "$REPO_DIR/.git" ]; then
        echo "[install] updating $REPO_DIR"
        git -C "$REPO_DIR" pull --ff-only
    else
        echo "[install] cloning $SANDBOX_REPO -> $REPO_DIR"
        mkdir -p "$(dirname "$REPO_DIR")"
        git clone "$SANDBOX_REPO" "$REPO_DIR"
    fi
fi

chmod +x "$REPO_DIR/cs" "$REPO_DIR"/*.sh 2>/dev/null || true

mkdir -p "$PREFIX"
ln -sf "$REPO_DIR/cs" "$PREFIX/cs"
echo "[install] linked $PREFIX/cs -> $REPO_DIR/cs"

# Sanity checks (warnings, not failures).
case ":$PATH:" in
    *":$PREFIX:"*) ;;
    *) echo "[install] WARNING: $PREFIX is not on your PATH -- add it to your shell rc" >&2 ;;
esac

if ! command -v podman >/dev/null 2>&1; then
    echo "[install] WARNING: podman not found. Install it, then 'podman machine init && podman machine start'." >&2
fi

echo "[install] done. Run 'cs' from any project directory."
