---
loop: warehouse-mode
product: sandbox
owner: dynamicalsystem
status: Closed
parent: null
blocked-by: []
worktrees:
  - /Users/dynamicalsystem/Documents/dynamicalsystem/sandbox.warehouse/main
prs:
  - https://github.com/dynamicalsystem/sandbox/pull/9
  - https://github.com/dynamicalsystem/sandbox/pull/10
triggers: []
---

# [ARCHIVED] Warehouse Mode

## Status

Closed

**Owner:** dynamicalsystem

## Context

The OODA skill expects a "warehouse" layout for every product: a bare clone with
per-branch worktrees (`main/` and `ooda/`). The sandbox repo is already set up
that way on the host at
`/Users/dynamicalsystem/Documents/dynamicalsystem/sandbox.warehouse/`.

Now we want the same experience inside the sandbox container: `git worktree list`
run from the user's working directory should see both `main` and `ooda`, and the
control plane should persist across container restarts. The current container
mounts the project at `/work`, which is a normal clone, so the `ooda` worktree is
invisible inside the sandbox.

## Observations

- The current sandbox container bind-mounts the project source to `/work` and
  starts the shell there.
- `git worktree list` only sees worktrees that share the same `.git` metadata; a
  separate `/work` clone does not see the warehouse's `ooda` worktree.
- The user's shell skills (`/orient`) run inside the container and rely on that
  command.
- The sandbox already mounts named volumes for per-agent config and bind-mounts
  host skill directories; extending the mount set is normal in this codebase.
- Putting the warehouse under an agent-specific directory like `~/.claude/`
  couples the control plane to one vendor. XDG directories are the neutral,
  conventional choice for persistent application data.

## Orientation

The warehouse root should live under `$XDG_DATA_HOME`, because it is persistent
user data (bare clones and worktrees), not transient state. The canonical path
will be:

```
$XDG_DATA_HOME/dynamicalsystem/warehouse/<product>/
```

with the usual fallback to `~/.local/share/dynamicalsystem/warehouse/<product>/`
when `$XDG_DATA_HOME` is unset.

To make `git worktree list` work inside the container with no path rewriting, the
warehouse must be mounted at the **same absolute path** inside the container that
it has on the host. Git's worktree `.git` files store absolute paths to the bare
repo; mounting at a different container path would break them. So the container
working directory becomes the host warehouse's `main/` worktree path, not `/work`.

Non-warehouse projects keep the existing `/work` behavior.

A sibling `<project>.warehouse/` path is also supported as a low-risk fallback
for existing setups (e.g. the current sandbox repo), but new products should use
the XDG layout.

## Decision

- Use `$XDG_DATA_HOME/dynamicalsystem/warehouse/<product>/` as the canonical
  warehouse root. All scripts reference `$XDG_DATA_HOME`, not a hardcoded default.
- Mount the warehouse into the container at the same absolute path it has on the
  host, and start the shell in `<warehouse>/main` when a warehouse is detected.
- Keep `/work` as the fallback for projects without a warehouse.
- Update the OODA and orient skills to document the XDG path and the cross-product
  registry at `$XDG_DATA_HOME/dynamicalsystem/augment/ooda-roots`.

## Action

- Implemented XDG-aware warehouse detection in `cs` and `cs.zsh`
  (https://github.com/dynamicalsystem/sandbox/pull/9).
- Updated the OODA and orient skills to document the XDG warehouse path and the
  cross-product registry at `$XDG_DATA_HOME/dynamicalsystem/augment/ooda-roots`
  (https://github.com/dynamicalsystem/augment/commit/f6afc4d).

## Outcomes

### Outcome 1: Inside the container `git worktree list` shows `main` and `ooda`

Tests:
- [x] `cs shell` from a warehouse-mode project starts in the warehouse `main/` worktree.
- [x] `git worktree list` run inside the container lists the bare repo, `main`, and `ooda`.
- [x] The `ooda/` directory is writable and persists across container restarts (same host path).

### Outcome 2: Non-warehouse projects keep working

Tests:
- [x] A project without a warehouse root still mounts at `/work` and `cs` behaves as before.
