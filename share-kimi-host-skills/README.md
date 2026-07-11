---
loop: share-kimi-host-skills
product: sandbox
owner: dynamicalsystem
status: Closed
parent: null
blocked-by: []
worktrees:
  - /Users/dynamicalsystem/Documents/dynamicalsystem/sandbox.warehouse/main
prs:
  - https://github.com/dynamicalsystem/sandbox/pull/6
triggers: []
---

# [ARCHIVED] Share Kimi Host Skills and AGENTS.md with Sandbox

## Status

Closed

**Owner:** dynamicalsystem

## Context

The user wants Kimi Code CLI inside the sandbox to load skills and the global
AGENTS.md from the host, so project-agnostic skills and system prompts stay on
the host and are shared across container runs. The host layout is:

- `~/.kimi-code/skills/` — user skills directory
- `~/.kimi-code/AGENTS.md` — symlink to `~/Documents/dynamicalsystem/augment/<github-username>-AGENTS.md`

Currently the sandbox mounts a named `kimi-config` volume at `/root/.kimi-code`,
so host `~/.kimi-code/skills/` and `AGENTS.md` are not visible inside the
container.

## Observations

- `cs` mounts `kimi-config:/root/.kimi-code` as a named volume.
- Named volumes are isolated from the host filesystem except for explicit bind
  mounts.
- Kimi Code CLI auto-discovers user skills under `~/.kimi-code/skills/` and loads
  `~/.kimi-code/AGENTS.md` as a global system prompt.
- The host `AGENTS.md` is a symlink; podman `-v` resolves symlinks and mounts the
  target file.
- Bind mounts can be nested under a volume mount (e.g. volume at `/root/.kimi-code`
  plus bind mounts at `/root/.kimi-code/skills` and `/root/.kimi-code/AGENTS.md`).

## Orientation

Keep the named volume for auth/config/session persistence, but bind mount the
host skills directory and AGENTS.md file into `/root/.kimi-code/` so Kimi sees
them. The mounts should be conditional so we do not create empty host directories
for users who have not set up Kimi skills. Read-only mounts are safest because
skills and AGENTS.md are host-managed content.

## Decision

1. In `cs`, detect host `~/.kimi-code/skills/` and `~/.kimi-code/AGENTS.md`.
2. If they exist, add read-only bind mounts into `/root/.kimi-code/skills` and
   `/root/.kimi-code/AGENTS.md` respectively.
3. Place these mounts after the `kimi-config` volume mount in the `podman run`
   command so the bind mounts overlay the volume correctly.
4. Document the host layout in README.md.

## Action

- Patched `cs` to conditionally mount host Kimi skills and AGENTS.md read-only.
- Updated README.md with the host-side setup instructions and `KIMI_HOST_DIR` knob.
- Tested that the skills directory and AGENTS.md symlink target are visible inside
  the container.
- Opened and merged PR #6 to `main`.

## Outcomes

### Outcome 1: Host Kimi skills are available inside the sandbox

Tests:
- [x] `cs shell` shows `/root/.kimi-code/skills/` populated when the host has
      `~/.kimi-code/skills/`.
- [x] Files inside the mounted skills dir match the host.

### Outcome 2: Host AGENTS.md is available as Kimi's global prompt

Tests:
- [x] `cs shell` shows `/root/.kimi-code/AGENTS.md` when the host has it.
- [x] The file content matches the symlink target on the host.

### Outcome 3: Existing auth/config persistence is unchanged

Tests:
- [x] `~/.kimi-code/config.toml` written by Kimi still persists across container
      restarts in the `kimi-config` volume.
- [x] Claude behaviour is unchanged.
