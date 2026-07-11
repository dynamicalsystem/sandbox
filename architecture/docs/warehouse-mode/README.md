# Decision: Warehouse Mode for the Sandbox

## Context

The OODA skill expects every product to keep its control plane in a Git warehouse:
a bare clone with `main/` and `ooda/` worktrees. The sandbox repo already had such
a warehouse on the host, but the container mounted the project at `/work` as a
normal clone, so `git worktree list` inside the container could not see the `ooda`
branch.

## Decision

- The canonical warehouse root is `$XDG_DATA_HOME/dynamicalsystem/warehouse/<product>/`,
  falling back to `~/.local/share/dynamicalsystem/warehouse/<product>/` when
  `$XDG_DATA_HOME` is unset. This avoids coupling the control plane to any
  agent-specific directory such as `~/.claude/`.
- The container mounts the warehouse at the **same absolute path** it has on the
  host, because Git worktree metadata stores absolute paths to the bare repo.
- When a warehouse is detected, the container shell starts in `<warehouse>/main`;
  otherwise the existing `/work` mount is used.
- A sibling `<project>.warehouse/` directory is still accepted as a low-risk
  fallback for existing setups.

## Consequences

- `cs shell` (or `cs <project>`) inside a warehouse project starts in the `main/`
  worktree, and `git worktree list` lists the bare repo, `main`, and `ooda`.
- Non-warehouse projects are unaffected.
- The cross-product registry referenced by the `/orient` skill moved from
  `~/.claude/ooda-roots` to `$XDG_DATA_HOME/dynamicalsystem/augment/ooda-roots`.

## References

- Implementation: https://github.com/dynamicalsystem/sandbox/pull/9
- OODA skill update: https://github.com/dynamicalsystem/augment/commit/f6afc4d
