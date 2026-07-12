:warning: This decision record is re-authored from the `product-worktrees` OODA loop. Do not merge the `ooda` branch.

# Decision: Product Worktrees

## Context

The `warehouse-mode` approach mounted a bare-repo warehouse and dropped the
agent into the `main/` worktree. That only supports one product worktree, which
is no different from a normal `git clone`. The OODA workflow needs multiple
active feature-branch worktrees (e.g. Fiona on `foo`, Bob on `bar`, Fiona
switching to review/fix `bar`).

## Decision

Use a per-product directory that contains the main clone and all worktrees:

```text
~/work/<product>/
├── main/          # normal clone on main
├── ooda/          # orphan ooda branch -- control plane
├── foo/           # feature/foo -- loop foo product worktree
└── bar-fix/       # feature/bar-fix -- loop bar-fix product worktree
```

- The `ooda` worktree holds loop docs and backlog; pushed direct to the `ooda`
  branch.
- Each loop drives a dedicated product worktree named for the loop.
- The sandbox mounts the sandbox worktree at `/work`, plus `main/` and `ooda/` at
  their host absolute paths so Git metadata resolves and `/orient` can read the
  control plane.
- `cs` accepts `--worktree <name>` to select the worktree explicitly.
- The `cs.zsh` wrapper defaults to `~/work/` and supports `cs <product>` and
  `cs <product> <loop>`.

## Consequences

- One container session = one loop worktree, mirroring Claude `--worktree` and
  GitHub Copilot parallel sessions.
- Context switching between loops is just `cs <product> <loop>`.
- No bare repo, no `warehouse` directory, no `dynamicalsystem`-namespaced path.

## References

- OODA loop: `sandbox.warehouse/ooda/product-worktrees/`
- OpenSpec change: `openspec/changes/product-worktrees/`
- Implementation PR: https://github.com/dynamicalsystem/sandbox/pull/12
