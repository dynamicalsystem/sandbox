---
loop: default-to-control-plane
product: sandbox
owner: dynamicalsystem
status: Closed
parent: product-worktrees
blocked-by: []
worktrees:
  - /Users/dynamicalsystem/work/sandbox/main
  - /Users/dynamicalsystem/work/sandbox/default-to-control-plane
prs:
  - https://github.com/dynamicalsystem/sandbox/pull/16
triggers: []
---

# [ARCHIVED] Default to Control Plane

## Status

Closed

**Owner:** dynamicalsystem

## Context

`cs <project>` (and `cs <model> <project>`) currently cd into
`~/work/<project>/main` before launching the sandbox. In the OODA per-product
layout, loop-scoped work already has its own form (`cs <project> <loop>`), so
the no-loop form is almost always an orientation session: reading the backlog,
reviewing loop docs, deciding the next action. That is control-plane work, and
it lives in the `ooda/` worktree, not `main/`.

## Observations

- Defaulting to `main/` invites editing main directly instead of going through
  a loop worktree, which is an anti-pattern in this workflow.
- The container mounts the launched worktree at `/work` plus `main/` and
  `ooda/` at host-absolute paths, so a session launched from `ooda/` can still
  read the product code in `main/`.
- `cs <project> main` already resolves `main` as a worktree name, so main
  stays one token away after the change.
- A worktree created mid-session is not mounted into the running container, so
  the natural flow is: orient in the control plane, write
  `ooda/<loop>/README.md`, exit, relaunch `cs <project> <loop>`.
- Non-OODA products have no `ooda/` worktree; the current `main/` default is
  the only sensible target there.
- The user base for this launcher is currently just us, so there is no
  least-surprise cost to changing the default.

## Orientation

Make the control plane the default landing spot for OODA products, with a
graceful fallback for everything else. Detection is a cheap directory-existence
check, consistent with how the layout is detected elsewhere.

## Decision

- In `cs.zsh`, when no loop is named, default to the `ooda` worktree when
  `~/work/<product>/ooda/` exists; otherwise keep the current `main` default.
- The default applies uniformly, including `cs <project> shell` and flag-only
  invocations such as `cs <project> --resume`.
- `cs <project> main` remains the way to land in the main worktree; document
  that bare `cs <project>` and `cs <project> ooda` are equivalent for OODA
  products.
- Do not touch the missing-loop creation prompt: the default is only ever a
  worktree that already exists, so the prompt path is unchanged.
- Update the sandbox `README.md` usage examples.

## Action

- [x] Document the new loop in `default-to-control-plane/README.md`.
- [x] Implement the `ooda`-first default in `cs.zsh`.
- [x] Update the sandbox `README.md` with the new behavior.
- [x] Test the default lands in `ooda/` for an OODA product.
- [x] Test the default falls back to `main/` for a non-OODA product.
- [x] Test `cs <project> main` still lands in `main/`.
- [x] Close the loop once the PR is merged.

## Outcomes

### Outcome 1: Bare project launches land in the control plane

Tests:
- [x] `cs myproj` cds into `~/work/myproj/ooda` when that worktree exists.
- [x] `cs kimi myproj` does the same with the agent prefix.
- [x] `cs myproj --resume` uses the `ooda` worktree and forwards the flag.

### Outcome 2: Non-OODA products are unaffected

Tests:
- [x] `cs myproj` cds into `~/work/myproj/main` when there is no `ooda/`
      worktree.

### Outcome 3: Main stays one token away

Tests:
- [x] `cs myproj main` cds into `~/work/myproj/main` without prompting.
- [x] `cs myproj <loop>` behavior is unchanged, including the creation prompt
      for missing loops.

## Verification notes

Exercised via a stub `cs` launcher and temporary project roots under both zsh
and bash: 16 checks covering the ooda default (bare, agent-prefixed, flag,
and `shell` forms), the non-OODA fallback to `main/`, explicit `main` and loop
names, and the non-interactive missing-loop error. All passed. Full container
launch was not run; the change only affects the host-side `cd` target.
