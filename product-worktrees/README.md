---
loop: product-worktrees
product: sandbox
owner: dynamicalsystem
status: Decide
parent: warehouse-mode
blocked-by: []
worktrees:
  - /Users/dynamicalsystem/Documents/dynamicalsystem/sandbox.warehouse/main
prs: []
triggers: []
---

# Product Worktrees

## Status

Decide

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

The right layout is a **per-project directory** that contains the main clone and
all of its worktrees. This keeps everything for one product in one place without
re-introducing a bare repo or a special `warehouse` concept.

```text
~/work/<product>/
├── main/          # normal clone, main branch
├── ooda/          # ooda orphan branch -- control plane
├── foo/           # feature/foo branch -- loop foo product worktree
└── bar-fix/       # feature/bar-fix branch -- loop bar-fix product worktree
```

- `main/` is just the project clone. The name makes the directory's role obvious.
- `ooda/` holds loop docs and is pushed direct to the orphan `ooda` branch.
- Each loop gets a product worktree named for the loop, branched from `main`.
- Git worktree metadata stores absolute paths, so the sandbox must mount any
  needed worktree at the same host absolute path inside the container.
- A container session should be scoped to a **single** product worktree, plus the
  `ooda` worktree and the `main/` repo metadata.

This is the same model GitHub Copilot and Claude's `--worktree` use for parallel
agent sessions, except the worktrees are loop-named and long-lived.

## Decision

- Adopt the per-project directory layout as the canonical OODA shape.
- Drop the bare-repo `warehouse` concept and the `dynamicalsystem` namespace path.
- Update the OODA and orient skills to describe the new layout.
- Update `cs` and `cs.zsh`:
  - `cs <product>` starts in `~/work/<product>/main`.
  - `cs <product> <loop>` starts in `~/work/<product>/<loop>` if it exists.
  - The container mounts the current worktree as `/work`, plus `main/` and
    `ooda/` at their host absolute paths for Git metadata and `/orient`.
- Deprecate/remove the warehouse-specific logic from `warehouse-mode`.
- Hand off implementation planning to OpenSpec.

## Action

- Record the decision in this loop.
- Create OpenSpec artifacts (`proposal.md`, `design.md`, `tasks.md`, specs) in
  the sandbox repo under `openspec/changes/product-worktrees/`.
- Present the proposal for approval before applying.

## Outcomes

### Outcome 1: Agent running in a product worktree can see the control plane

Tests:
- [ ] `cs shell` from `~/work/musters/foo/` starts in `/work` and can read
      `~/work/musters/ooda/`.
- [ ] `git worktree list` inside the container lists `main`, `ooda`, and the
      current loop worktree.
- [ ] `/orient` inside the container can read loop docs from the `ooda` worktree.

### Outcome 2: Wrapper can jump to main or a loop worktree

Tests:
- [ ] `cs musters` starts the container in `~/work/musters/main/`.
- [ ] `cs musters foo` starts the container in `~/work/musters/foo/` if it exists.

### Outcome 3: Existing single-directory workflow still works

Tests:
- [ ] A project without an `ooda` worktree still mounts at `/work` and behaves as
      before.

### Outcome 4: OODA skill documents the new layout

Tests:
- [ ] The OODA skill describes the per-project directory layout.
- [ ] The orient skill uses the same discovery rule to find the `ooda` worktree.
