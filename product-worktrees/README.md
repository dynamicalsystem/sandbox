---
loop: product-worktrees
product: sandbox
owner: dynamicalsystem
status: Observe
parent: warehouse-mode
blocked-by: []
worktrees:
  - /Users/dynamicalsystem/Documents/dynamicalsystem/sandbox.warehouse/main
prs: []
triggers: []
---

# Product Worktrees

## Status

Observe

**Owner:** dynamicalsystem

## Context

The `warehouse-mode` loop got the control plane mounted inside the sandbox, but it
drops the user into the warehouse `main/` worktree. That only supports a single
product worktree, which is no different from a normal `git clone`.

The OODA skill actually expects the data plane to be **one worktree per active
feature branch**, with each product worktree driven by a loop. The scenario is:
Fiona is implementing `foo` on one loop, Bob implemented `bar` on another, `bar`
is merged, a bug appears in `bar`, and Fiona has to look at it while her `foo`
work remains untouched. That needs multiple product worktrees.

So the sandbox needs to support:

- a product worktree for the current loop (where the agent edits code), and
- the `ooda` control-plane worktree (where `/orient` reads loop docs).

## Observations

- `warehouse-mode` mounts the warehouse root and starts the shell in `main/`.
- A single product worktree cannot support the Fiona/Bob scenario.
- The OODA skill frontmatter has `worktrees:` for the data-plane worktrees a loop
drives.
- The current `cs` wrapper maps a project name to a single directory; it has no
notion of loop-named worktrees.
- Git worktree metadata stores absolute paths, so any mounted worktree must be
at the same absolute path inside the container.

## Orientation

There are two plausible layouts:

1. **Keep the bare warehouse** (`<product>.warehouse/.bare`, `main/`, `ooda/`)
   and place loop-named product worktrees next to it (e.g.
   `<product>-<loop>/`). The sandbox mounts the current product worktree plus the
   warehouse paths needed for git metadata and the `ooda` worktree.

2. **Drop the warehouse entirely.** The product repo itself is the `main`
   worktree. The `ooda` branch is checked out as a sibling worktree
   (`<product>-ooda/`). Each loop's code changes happen in a sibling worktree
   named for the loop (`<product>-<loop>/`). The sandbox mounts the current
   worktree and the `ooda` worktree.

Option 2 is simpler: no bare clone, no extra `warehouse` concept, just standard
Git worktrees. It also removes the `dynamicalsystem` namespace problem entirely.
The OODA skill would need to be updated to describe this layout as the default.

## Decision

Pending user confirmation:

- Adopt option 2 (normal clone + sibling worktrees) as the canonical OODA layout.
- Update the OODA skill to match.
- Update `cs` to detect that the launch directory is a Git worktree, find the
  sibling `ooda` worktree, and mount both at their host absolute paths.
- Deprecate or remove the warehouse-specific logic added in `warehouse-mode`.

## Action

None yet. Awaiting decision on layout and scope.

## Outcomes

### Outcome 1: Agent running in a product worktree can see the control plane

Tests:
- [ ] `cs shell` from `musters-foo/` starts in `musters-foo/` and can read
      `musters-ooda/`.
- [ ] `git worktree list` inside the container lists at least the current worktree
      and the `ooda` worktree.
- [ ] `/orient` inside the container can read loop docs from the `ooda` worktree.

### Outcome 2: Existing single-directory workflow still works

Tests:
- [ ] A project without an `ooda` worktree still mounts at `/work` and behaves as
      before.
