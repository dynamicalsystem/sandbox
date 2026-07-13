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

When the requested loop worktree does not exist, `cs.zsh` should ask the user
whether to create it, defaulting to yes. This keeps the common path fast (one
extra `[Enter]` to confirm) while still guarding against typos. In
non-interactive contexts where stdin is not a tty, the wrapper should fall back
to its current error behavior so scripts do not hang.

Creation should:

1. Add a Git worktree from `main/` at `../<loop>/`.
2. Create `../ooda/<loop>/README.md` from a standard loop template.
3. Continue launching the agent from the newly created worktree.

## Decision

- When `cs.zsh` resolves a loop worktree that does not exist, and stdin is a tty,
  print `Loop "<loop>" does not exist. Create it? [Y/n]` and read a response.
  - Empty input or input starting with `y` or `Y` creates the loop.
  - Any other input aborts with an error.
- In non-interactive contexts (stdin is not a tty), keep the current error
  behavior instead of prompting.
- When creation is confirmed:
  - Run `git -C ~/work/<product>/main worktree add ../<loop>`.
  - Create `~/work/<product>/ooda/<loop>/README.md` with the standard loop
    frontmatter template.
- If the loop already exists, launch normally without prompting.
- Update `README.md` usage examples to show the prompt.
- Do not add a `--no-create` flag yet; abort non-interactive invocations with the
  existing error and revisit if scripting use cases appear.

## Action

- [x] Document the new loop in `auto-create-loop-worktree/README.md`.
- [ ] Implement interactive loop-creation prompting in `cs.zsh`.
- [ ] Add a loop README template that `cs.zsh` can copy into `ooda/<loop>/`.
- [ ] Update the sandbox `README.md` with the new behavior.
- [ ] Test `cs myproj new-loop` creates the loop on confirmation.
- [ ] Test `cs myproj new-loop` aborts when the user declines.
- [ ] Test `cs kimi myproj new-loop` creates the loop on confirmation.
- [ ] Verify that a missing loop in a non-interactive context still errors.
- [ ] Close the loop once the PR is merged.

## Outcomes

### Outcome 1: Missing loop prompts to create, defaulting to yes

Tests:
- [ ] `cs myproj new-loop` prompts `Loop "new-loop" does not exist. Create it? [Y/n]`.
- [ ] Pressing `Enter` creates `~/work/myproj/new-loop/` and
      `~/work/myproj/ooda/new-loop/README.md`, then launches Claude inside the
      new worktree.
- [ ] Answering `n` aborts without creating anything.
- [ ] An existing loop launches normally without prompting.

### Outcome 2: Agent prefix works with the prompt

Tests:
- [ ] `cs kimi myproj new-loop` prompts and creates the worktree when confirmed.
- [ ] `cs claude myproj new-loop` is equivalent to the no-agent-prefix form.

### Outcome 3: Non-interactive contexts stay safe

Tests:
- [ ] Running `cs myproj new-loop` with stdin not a tty errors instead of
      hanging.
- [ ] The error message still names the missing worktree path.

### Outcome 4: Control plane is bootstrapped for the new loop

Tests:
- [ ] `~/work/myproj/ooda/new-loop/README.md` is created with valid frontmatter.
- [ ] `/orient` inside the container can read the new loop doc from the `ooda`
      worktree.
