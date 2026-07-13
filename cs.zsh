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

# Ask the user whether to create a missing loop worktree. Returns 0 on yes,
# 1 on no or when stdin is not a tty (so scripts do not hang).
__cs_prompt_create_loop() {
    local loop="$1"
    if [ ! -t 0 ]; then
        return 1
    fi
    printf 'Loop "%s" does not exist. Create it? [Y/n] ' "$loop" >&2
    local answer
    read -r answer
    case "$answer" in
        ''|[Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# Create the data-plane worktree and a skeleton control-plane directory for a
# new loop. Returns 0 on success.
__cs_create_loop() {
    local base="$1" product="$2" loop="$3"
    local main_dir="$base/$product/main"
    local loop_dir="$base/$product/$loop"
    local ooda_loop_dir="$base/$product/ooda/$loop"

    if [ ! -d "$main_dir" ]; then
        echo "cs: missing main worktree: $main_dir" >&2
        return 1
    fi

    if ! git -C "$main_dir" worktree add "../$loop"; then
        echo "cs: failed to create worktree: $loop_dir" >&2
        return 1
    fi

    mkdir -p "$ooda_loop_dir"

    # Locate the loop README template next to this sourced file.
    local script_path
    if [ -n "${ZSH_VERSION:-}" ]; then
        script_path="${(%):-%x}"
    else
        script_path="${BASH_SOURCE[0]}"
    fi
    local sandbox_dir
    sandbox_dir="$(cd -P "$(dirname "$script_path")" >/dev/null 2>&1 && pwd)"
    local template="$sandbox_dir/templates/loop-README.md"

    if [ -f "$template" ]; then
        local owner
        owner="$(git config user.name 2>/dev/null || true)"
        [ -z "$owner" ] && owner="dynamicalsystem"
        sed -e "s/{{LOOP}}/$loop/g" \
            -e "s/{{PRODUCT}}/$product/g" \
            -e "s/{{OWNER}}/$owner/g" \
            "$template" > "$ooda_loop_dir/README.md"
    fi
}

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
            elif __cs_prompt_create_loop "$loop"; then
                __cs_create_loop "$base" "$product" "$loop" || return 1
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
