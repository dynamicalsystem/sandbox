---
loop: auto-create-loop-worktree
product: sandbox
owner: dynamicalsystem
status: Open
parent: product-worktrees
blocked-by: []
worktrees:
  - /Users/dynamicalsystem/work/sandbox/main
prs: []
triggers: []
---

# Auto-Create Loop Worktree

## Status

Open

**Owner:** dynamicalsystem

## Context

The per-product layout introduced by `product-worktrees` lets agents work in
loop-named product worktrees. `cs.zsh` already supports `cs <project> <loop>`
and `cs <model> <project> <loop>`, but only when the target worktree already
exists. If it does not, the wrapper errors out and the user has to create the
worktree and its control-plane directory by hand before launching the agent.

A loop in this OODA setup needs two things:

1. A data-plane worktree at `~/work/<product>/<loop>/`, branched from `main/`.
2. A control-plane directory at `~/work/<product>/ooda/<loop>/` for loop docs.

Creating both manually is repetitive and easy to get wrong, especially when the
agent is the one discovering that a new loop is needed.

## Observations

- `cs.zsh` parses `cs <model> <project> <loop>` by stripping the optional agent
  prefix, treating the next token as the product, and the following token as the
  loop name.
- If `~/work/<product>/<loop>/` is missing, `cs.zsh` prints
  `cs: no such project or worktree: <target>` and exits.
- Creating a loop by hand currently requires:
  - `cd ~/work/<product>/main && git worktree add ../<loop>`
  - `mkdir -p ~/work/<product>/ooda/<loop>`
  - Copying or writing a `README.md` with the loop frontmatter.
- The launcher itself does not need to run inside the container to create a
  worktree; the host Git installation can do it before the container starts.
- Auto-creating a loop silently would be risky (typos would spawn unwanted
  worktrees), so creation must be explicit.

## Orientation

Add an opt-in `--create` flag to `cs.zsh` (and document it in `cs`) that, when
the requested loop worktree does not exist, creates it before launching the
container. The flag should be passed after the loop name so the existing
positional syntax is unchanged.

Creation should:

1. Add a Git worktree from `main/` at `../<loop>/`.
2. Create `../ooda/<loop>/README.md` from a standard loop template.
3. Continue launching the agent from the newly created worktree.

Without `--create`, the wrapper keeps its current safe behavior of erroring on
a missing loop.

## Decision

- Extend `cs.zsh` to recognize a trailing `--create` flag after the loop name.
- When `--create` is present and `~/work/<product>/<loop>/` does not exist:
  - Run `git -C ~/work/<product>/main worktree add ../<loop>`.
  - Create `~/work/<product>/ooda/<loop>/README.md` with the standard loop
    frontmatter template.
- If the loop already exists, ignore `--create` and launch normally.
- If `--create` is omitted and the loop is missing, keep the existing error.
- Update `README.md` usage examples to include the new flag.
- Do not implement interactive prompts or environment-variable overrides yet;
  keep the surface small until usage proves they are needed.

## Action

- [ ] Document the new loop in `auto-create-loop-worktree/README.md`.
- [ ] Implement `--create` parsing and worktree creation in `cs.zsh`.
- [ ] Add a loop README template that `cs.zsh` can copy into `ooda/<loop>/`.
- [ ] Update the sandbox `README.md` with the new usage.
- [ ] Test `cs myproj new-loop --create`.
- [ ] Test `cs kimi myproj new-loop --create`.
- [ ] Verify that a missing loop without `--create` still errors.
- [ ] Close the loop once the PR is merged.

## Outcomes

### Outcome 1: `cs <project> <loop> --create` creates and enters a new loop

Tests:
- [ ] `cs myproj new-loop --create` creates `~/work/myproj/new-loop/` and
      `~/work/myproj/ooda/new-loop/README.md`, then launches Claude inside the
      new worktree.
- [ ] `cs myproj new-loop` (without `--create`) still errors if the worktree is
      missing.
- [ ] `cs myproj new-loop --create` launches normally if the worktree already
      exists.

### Outcome 2: Agent prefix works with the new flag

Tests:
- [ ] `cs kimi myproj new-loop --create` creates the worktree and launches Kimi.
- [ ] `cs claude myproj new-loop --create` is equivalent to the no-agent-prefix
      form.

### Outcome 3: Control plane is bootstrapped for the new loop

Tests:
- [ ] `~/work/myproj/ooda/new-loop/README.md` is created with valid frontmatter.
- [ ] `/orient` inside the container can read the new loop doc from the `ooda`
      worktree.
