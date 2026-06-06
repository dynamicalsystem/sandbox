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
#   cs shell            # interactive shell in the sandbox ($PWD)
#   cs rebuild          # rebuild the image
#
# Override the projects root with CS_PROJECT_ROOT. Portable across zsh and bash.
# (A project literally named "shell" or "rebuild" is shadowed by those
# subcommands -- run the launcher from inside it instead.)

cs() {
    local base="${CS_PROJECT_ROOT:-$HOME/Documents/dynamicalsystem}"
    case "${1:-}" in
        ''|-*|shell|rebuild)
            # No project argument -- run the launcher in the current directory.
            command cs "$@"
            ;;
        *)
            # First argument names a project under $base: cd in, then launch.
            if [ -d "$base/$1" ]; then
                cd "$base/$1" || return
                shift
                command cs "$@"
            else
                echo "cs: no such project: $base/$1" >&2
                return 1
            fi
            ;;
    esac
}

# The terminal title (repo/dir name) is set by the `cs` launcher itself, so it
# works however cs is invoked -- nothing to do here.
