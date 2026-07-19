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
#   PREFIX                         bin dir for the `cs` symlink          (default ~/.local/bin)
#   SHELL_RC                       rc file to source the cs() helper from (default ~/.zshrc)
#   SANDBOX_SKIP_PODMAN_LAUNCHAGENT  set 1 to skip the macOS LaunchAgent install
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

chmod +x "$REPO_DIR/cs" "$REPO_DIR"/*.sh "$REPO_DIR"/scripts/*.sh 2>/dev/null || true

mkdir -p "$PREFIX"
ln -sf "$REPO_DIR/cs" "$PREFIX/cs"
echo "[install] linked $PREFIX/cs -> $REPO_DIR/cs"

# Shell helper: a `cs()` function that cd's into ~/Documents/dynamicalsystem/<arg>
# before launching the sandbox (see cs.zsh). We source the repo file from the
# user's rc rather than copying it, so 'git pull' updates the helper too. The
# block is delimited by markers and rewritten idempotently on every install.
SHELL_RC="${SHELL_RC:-$HOME/.zshrc}"
BEGIN_MARK="# >>> cs sandbox (cd-to-project helper) >>>"
END_MARK="# <<< cs sandbox (cd-to-project helper) <<<"

mkdir -p "$(dirname "$SHELL_RC")"
touch "$SHELL_RC"
tmp="$(mktemp)"
# Strip any previous block (markers included), keeping everything else.
awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0==b { skip=1 }
    skip && $0==e { skip=0; next }
    !skip { print }
' "$SHELL_RC" > "$tmp"
{
    printf '%s\n' "$BEGIN_MARK"
    printf '[ -f "%s/cs.zsh" ] && source "%s/cs.zsh"\n' "$REPO_DIR" "$REPO_DIR"
    printf '%s\n' "$END_MARK"
} >> "$tmp"
mv "$tmp" "$SHELL_RC"
echo "[install] sourced cs() helper from $REPO_DIR/cs.zsh in $SHELL_RC"
echo "[install] open a new shell (or 'source $SHELL_RC') to use 'cs <project>'"

# Sanity checks (warnings, not failures).
case ":$PATH:" in
    *":$PREFIX:"*) ;;
    *) echo "[install] WARNING: $PREFIX is not on your PATH -- add it to your shell rc" >&2 ;;
esac

if ! command -v podman >/dev/null 2>&1; then
    echo "[install] WARNING: podman not found. Install it, then 'podman machine init && podman machine start'." >&2
fi

# On macOS, install a LaunchAgent that keeps the Podman machine running across logins.
if [ "$(uname -s)" = "Darwin" ] && [ "${SANDBOX_SKIP_PODMAN_LAUNCHAGENT:-0}" != "1" ]; then
    if [ -f "$REPO_DIR/scripts/install-podman-launchagent.sh" ]; then
        "$REPO_DIR/scripts/install-podman-launchagent.sh"
    else
        echo "[install] WARNING: Podman LaunchAgent installer not found at $REPO_DIR/scripts/install-podman-launchagent.sh" >&2
    fi
fi

echo "[install] done. Run 'cs' from any project directory."
