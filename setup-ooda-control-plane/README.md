---
loop: setup-ooda-control-plane
product: sandbox
owner: dynamicalsystem
status: Act
parent: null
blocked-by: []
worktrees:
  - /Users/dynamicalsystem/Documents/dynamicalsystem/sandbox.warehouse/main
prs: []
triggers: []
---

# Setup OODA Control Plane

## Status

Act

**Owner:** dynamicalsystem

## Context

This product currently has no OODA control plane. Work is tracked informally in
conversation, which makes it hard to connect decisions to actions and to verify
outcomes. We need a lightweight control plane where loops live separately from
the product code but remain tied to the repo.

## Observations

- `git worktree list` showed only the main worktree; no `ooda` branch worktree
  existed.
- No in-tree `ooda/` directory existed as a fallback.
- No `~/.claude/ooda-roots` registry was present.
- The repo has an existing branch `persist-auth-and-cd-helper` alongside `main`.

## Orientation

The warehouse pattern (bare clone + per-branch worktrees) keeps the control
plane disjoint from `main` while still living in the same GitHub repo. This
matches the OODA skill's default recommendation and avoids polluting the data
plane with loop scaffolding. The local Git version does not support `git
worktree add --orphan`, so the orphan `ooda` branch must be created via `git
checkout --orphan` in an existing worktree and then checked out into its own
worktree.

## Decision

Stand up the warehouse at `sandbox.warehouse/` next to the product repo:

1. Create a bare clone of `dynamicalsystem/sandbox`.
2. Add a `main` worktree for the data plane.
3. Create an orphan `ooda` branch and add a dedicated worktree for it.
4. Seed the control plane with `backlog.md` and this loop.
5. Push the `ooda` branch direct to origin.

## Action

- Warehouse created at `/Users/dynamicalsystem/Documents/dynamicalsystem/sandbox.warehouse/`.
- `ooda` orphan branch bootstrapped and pushed.
- `setup-ooda-control-plane` loop created with this README.

## Outcomes

### Outcome 1: `/orient` can find and read the sandbox control plane

Tests:
- [x] `git worktree list` run from the bare clone shows `main` and `ooda` worktrees.
- [x] `backlog.md` exists at the ooda worktree root.
- [x] This loop's README.md is parseable and has valid frontmatter.

### Outcome 2: The `ooda` branch is available on the remote

Tests:
- [x] `git push origin ooda` succeeds.
- [ ] The remote `ooda` branch is visible via `git ls-remote origin ooda`.
