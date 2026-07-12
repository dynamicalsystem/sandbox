# cs.zsh -- shell wrapper for the `cs` sandbox launcher.
#
# Sourced from your ~/.zshrc by install.sh. Defines a `cs` function that, when
# given a project name, cd's into that project's per-product directory before
# launching the sandbox. With no project (or a known subcommand/flag) it behaves
# exactly like the underlying `cs` launcher in the current directory.
#
#   cs                      # sandbox in $PWD
#   cs myproj               # cd ~/work/myproj/main, then sandbox
#   cs myproj foo           # cd ~/work/myproj/foo, then sandbox
#   cs myproj --worktree foo  # explicit form of the above
#   cs myproj --resume      # cd ~/work/myproj/main, pass --resume to agent
#   cs kimi myproj foo      # cd ~/work/myproj/foo, then kimi
#   cs shell                # interactive shell in the sandbox ($PWD)
#   cs rebuild              # rebuild the image
#
# Override the projects root with CS_PROJECT_ROOT. Portable across zsh and bash.
# (A project literally named "shell", "rebuild", or "kimi" is shadowed by those
# subcommands -- run the launcher from inside it instead.)

cs() {
    local base="${CS_PROJECT_ROOT:-$HOME/work}"
    local prefix=()

    # Optional agent subcommand (e.g. `kimi`) can precede the project name.
    case "${1:-}" in
        kimi)
            prefix+=("$1")
            shift
            ;;
    esac

    case "${1:-}" in
        ''|-*|shell|rebuild)
            # No project argument -- run the launcher in the current directory.
            command cs "${prefix[@]}" "$@"
            ;;
        *)
            # First argument is the product name.
            local product="$1"
            shift
            local loop="main"
            local remaining=()

            # If the next argument is a launcher subcommand or a flag, stay on
            # the main worktree. If it's a loop name or --worktree, use that.
            if [ "$#" -gt 0 ]; then
                case "$1" in
                    shell|rebuild)
                        remaining+=("$@")
                        ;;
                    --worktree)
                        shift
                        loop="${1:-}"
                        if [ -z "$loop" ]; then
                            echo "cs: --worktree requires a name" >&2
                            return 1
                        fi
                        shift
                        remaining+=("$@")
                        ;;
                    -*)
                        remaining+=("$@")
                        ;;
                    *)
                        loop="$1"
                        shift
                        remaining+=("$@")
                        ;;
                esac
            fi

            local target="$base/$product/$loop"
            if [ -d "$target" ]; then
                cd "$target" || return
                command cs "${prefix[@]}" "${remaining[@]}"
            else
                echo "cs: no such project or worktree: $target" >&2
                return 1
            fi
            ;;
    esac
}

# The terminal title (repo/dir name) is set by the `cs` launcher itself, so it
# works however cs is invoked -- nothing to do here.
