# Proposal: Product Worktrees

## Problem

The current sandbox `warehouse-mode` mounts the entire OODA warehouse and drops
the agent into the `main/` worktree. That only supports one product worktree,
which is no different from a normal `git clone`.

The OODA workflow requires multiple active product worktrees:

- Fiona is implementing `foo`.
- Bob implemented `bar` and it is merged.
- A bug appears in `bar`; Bob is away, so Fiona must fix it while her `foo`
  work remains untouched.

This needs loop-named product worktrees plus a control-plane worktree that the
agent can read from inside the sandbox.

## Scope

In scope:

- Define the canonical per-product directory layout.
- Update the OODA and orient skills to describe the layout.
- Update `cs` and `cs.zsh` to mount and enter the correct worktree.
- Deprecate/remove the warehouse-specific logic from `warehouse-mode`.

Out of scope:

- Automating the creation of loop worktrees (manual `git worktree add` for now).
- Changing the container image, firewall, or agent auth flows.

## Approach

Use a per-product directory that contains the main clone and all worktrees:

```text
~/work/<product>/
├── main/          # normal clone, main branch
├── ooda/          # control-plane worktree on the orphan ooda branch
├── foo/           # loop foo product worktree
└── bar-fix/       # loop bar-fix product worktree
```

The sandbox scopes each container session to a single worktree:

- `/work` is the worktree `cs` was launched from.
- `<product>/main/` is mounted at its host absolute path for shared `.git`
  metadata.
- `<product>/ooda/` is mounted at its host absolute path so `/orient` can read
  loop docs.

This mirrors how Claude `--worktree` and GitHub Copilot isolate parallel agent
sessions, except the worktrees are loop-named and long-lived.

## Non-goals

- Do not introduce a bare-repo warehouse or a `dynamicalsystem`-namespaced path.
- Do not make the container see every loop worktree; one session sees only its
  own worktree plus the control plane.
