---
loop: warehouse-mode
product: sandbox
owner: dynamicalsystem
status: Orient
parent: null
blocked-by: []
worktrees:
  - /Users/dynamicalsystem/Documents/dynamicalsystem/sandbox.warehouse/main
prs: []
triggers: []
---

# Warehouse Mode

## Status

Orient

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

- On the host the warehouse root is
  `/Users/dynamicalsystem/Documents/dynamicalsystem/sandbox.warehouse/`.
- The container currently bind-mounts the project source to `/work` and starts the
  shell there.
- `git worktree list` only sees worktrees that share the same `.git` metadata; a
  separate `/work` clone does not see the warehouse's `ooda` worktree.
- The user's shell skills (`/orient`) run inside the container and rely on that
  command.
- The sandbox already mounts named volumes for per-agent config and bind-mounts
  host skill directories; extending the mount set is normal in this codebase.

## Orientation

Two broad ways to make the warehouse visible inside the container:

1. **Work from the warehouse `main/` worktree.** Mount the entire warehouse root
   into the container (e.g. at `/warehouse/sandbox`) and start the shell in
   `/warehouse/sandbox/main`. `git worktree list` then works unchanged because the
   working directory is part of the warehouse. The control-plane `ooda/` folder
   is naturally available, read-write, and persists with the host.

2. **Keep `/work` as the working tree and add a separate mount for `ooda/`.**
   This avoids changing the working directory but breaks the skill's assumption
   that `git worktree list` from cwd reveals the `ooda` branch; we'd need a
   fallback in `/orient` or in the container's `git` setup.

Option 1 is lower friction and matches the skill's wording. The main open
questions are the exact host path for the warehouse and how to expose it without
surprising users who expect `/work`.

## Decision

Pending user confirmation:

- Use `~/.claude/warehouse/<product>/` on the host as the canonical warehouse root
  (already established in the `musters` discussion).
- For sandbox, mount the warehouse into the container at `/warehouse/sandbox`.
- Start the container shell in `/warehouse/sandbox/main` instead of `/work` when
  the project is in warehouse mode.
- Keep `/work` as a fallback for non-warehouse projects or for backward
  compatibility.

## Action

None yet. Awaiting confirmation of the warehouse mount path and working-directory
behavior.

## Outcomes

### Outcome 1: Inside the container `git worktree list` shows `main` and `ooda`

Tests:
- [ ] `cs shell` from a warehouse-mode project starts in `/warehouse/<product>/main`.
- [ ] `git worktree list` run inside the container lists the bare repo, `main`, and `ooda`.
- [ ] The `ooda/` directory is writable and survives a container restart.

### Outcome 2: Non-warehouse projects keep working

Tests:
- [ ] A project without a warehouse root still mounts at `/work` and `cs` behaves as before.
