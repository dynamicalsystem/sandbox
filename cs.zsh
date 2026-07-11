# cs.zsh -- shell wrapper for the `cs` sandbox launcher.
#
# Sourced from your ~/.zshrc by install.sh. Defines a `cs` function that, when
# given a project name, cd's into it under your dynamicalsystem projects root
# before launching the sandbox. With no project (or a known subcommand/flag) it
# behaves exactly like the underlying `cs` launcher in the current directory.
#
#   cs                  # sandbox in $PWD (claude --dangerously-skip-permissions)
#   cs myproj           # cd ~/Documents/dynamicalsystem/myproj, then sandbox there
#   cs myproj --resume  # cd, then pass the remaining args through to claude
#   cs kimi             # sandbox in $PWD (kimi --yolo)
#   cs kimi myproj      # cd ~/Documents/dynamicalsystem/myproj, then kimi --yolo
#   cs shell            # interactive shell in the sandbox ($PWD)
#   cs rebuild          # rebuild the image
#
# Override the projects root with CS_PROJECT_ROOT. Portable across zsh and bash.
# (A project literally named "shell", "rebuild", or "kimi" is shadowed by those
# subcommands -- run the launcher from inside it instead.)

cs() {
    local base="${CS_PROJECT_ROOT:-$HOME/Documents/dynamicalsystem}"
    local prefix=()

    # Optional agent subcommand (e.g. `kimi`) can precede the project name.
    case "${1:-}" in
        kimi)
            prefix+=("$1")
            shift
            ;;
    esac

    local warehouse_root="${CLAUDE_SANDBOX_WAREHOUSE_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/dynamicalsystem/warehouse}"

    case "${1:-}" in
        ''|-*|shell|rebuild)
            # No project argument -- run the launcher in the current directory.
            command cs "${prefix[@]}" "$@"
            ;;
        *)
            # First remaining argument names a project under $base. Prefer its
            # warehouse main/ worktree if one exists, otherwise fall back to the
            # plain project directory.
            local repo="$base/$1"
            local target="$repo"
            if [ -d "$warehouse_root/$1/main" ]; then
                target="$warehouse_root/$1/main"
            elif [ -d "$repo.warehouse/main" ]; then
                target="$repo.warehouse/main"
            fi
            if [ -d "$target" ]; then
                cd "$target" || return
                shift
                command cs "${prefix[@]}" "$@"
            else
                echo "cs: no such project: $base/$1" >&2
                return 1
            fi
            ;;
    esac
}

# The terminal title (repo/dir name) is set by the `cs` launcher itself, so it
# works however cs is invoked -- nothing to do here.
