---
loop: support-kimi-in-sandbox
product: sandbox
owner: dynamicalsystem
status: Closed
parent: null
blocked-by: []
worktrees:
  - /Users/dynamicalsystem/work/sandbox/main
prs:
  - https://github.com/dynamicalsystem/sandbox/pull/2
triggers: []
---

# [ARCHIVED] Support Kimi in Sandbox

## Status

Closed

**Owner:** dynamicalsystem

## Context

The user wants to evaluate Kimi as an alternative to Claude Code inside the
same rootless Podman sandbox. The current `cs` launcher is Claude-specific:
image name, installed CLI, command name, skip-permissions flag, config volume,
and onboarding seeding all assume Anthropic's `claude` binary. The goal is to
make the sandbox work with both agents, with Kimi running in its equivalent of
"dangerous mode" (unfettered permissions inside the container).

## Observations

- `cs` hardcodes `claude` and `claude --dangerously-skip-permissions` as the
  only inside-container command.
- `Containerfile` installs `@anthropic-ai/claude-code@2.1.206` globally via npm.
- `entrypoint.sh` seeds `/root/.claude.json` with `hasCompletedOnboarding`.
- Config persistence uses a named volume `claude-config` mounted at `/root/.claude`.
- Image tag is `claude-sandbox:latest`; hostname is `claude-sandbox`.
- `cs.zsh` wrapper forwards args blindly; subcommands `shell` and `rebuild` are
  intercepted, everything else is passed to `claude`.
- Environment forwarding in `cs` is Claude-centric (`ANTHROPIC_API_KEY`,
  `CLAUDE_CODE_OAUTH_TOKEN`, `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`,
  `CLAUDE_CODE_DISABLE_MOUSE_CLICKS`).
- The global allowlist path is `/etc/claude-sandbox/allowed-domains.txt`.

## Orientation

- Kimi Code CLI is published as `@moonshot-ai/kimi-code` on npm and installs a
  `kimi` binary. ([Kimi Code CLI docs](https://www.kimi.com/en-cn/help/kimi-code/cli-getting-started))
- Kimi's equivalent to Claude's `--dangerously-skip-permissions` is `--yolo`,
  which auto-approves regular tool calls. ([`kimi` command reference](https://www.kimi.com/code/docs/en/kimi-code-cli/reference/kimi-command.html))
- Kimi stores config/session data under `~/.kimi/` (formerly `~/.kimi-code/`);
  the docs also reference `KIMI_CODE_HOME` for relocation. It supports
  `KIMI_API_KEY`, `KIMI_BASE_URL`, `KIMI_MODEL`, and `KIMI_MAX_TOKENS` env vars.
  ([Kimi customization docs](https://www.kimi.com/en-cn/help/kimi-code/cli-customization))
- A separate config volume for Kimi avoids colliding with Claude's state and
  keeps each agent's sessions/auth isolated.
- CLI UX: keep `cs` as the default Claude launcher for backward compatibility,
  add `cs kimi` as an explicit subcommand. The `cs.zsh` wrapper must learn
  `kimi` as a reserved word so it is not treated as a project name.
- Image name `claude-sandbox:latest` is already configurable via
  `CLAUDE_SANDBOX_IMAGE`; changing the default would break installed launchers,
  so leave it as-is.

## Decision

Make the sandbox agent-agnostic while keeping Claude as the default:

1. Install `@moonshot-ai/kimi-code` in the `Containerfile` alongside Claude.
2. Add `kimi` as a `cs` subcommand: `cs kimi` runs `kimi --yolo` inside the
   container; `cs kimi <args>` passes args through.
3. Add a dedicated `kimi-config` volume mounted at `/root/.kimi`.
4. Forward Kimi env vars (`KIMI_API_KEY`, `KIMI_BASE_URL`, `KIMI_MODEL`,
   `KIMI_MAX_TOKENS`) when set.
5. Update `cs.zsh` to treat `kimi` as a launcher subcommand, not a project name.
6. Keep `cs`, `cs shell`, `cs rebuild`, and the project-name helper unchanged.

## Action

- Patched `Containerfile` to install `@moonshot-ai/kimi-code@0.23.5`.
- Patched `cs` to recognize the `kimi` subcommand, default to `kimi --yolo`,
  mount the `kimi-config` volume, and forward `KIMI_*` env vars.
- Patched `cs.zsh` to add `kimi` to the reserved subcommand list.
- Updated `README.md` with usage examples and the new `CLAUDE_SANDBOX_KIMI_CONFIG_VOLUME` knob.
- Rebuilt the image and verified `cs --version`, `cs kimi --version`, and
  `cs shell` (both binaries present on PATH).
- Opened PR #2 promoting the changes to `main`.

## Outcomes

### Outcome 1: Kimi can be launched inside the sandbox in dangerous mode

Tests:
- [x] `cs kimi` starts a Kimi session inside the container.
- [x] The launched process includes `--yolo` (verified by launcher code path;
  interactive runtime verification requires a valid Kimi API key).
- [x] The container still applies the egress allowlist by default.

### Outcome 2: Existing Claude behaviour is unchanged

Tests:
- [x] `cs` still launches Claude with `--dangerously-skip-permissions`.
- [x] `cs shell` and `cs rebuild` still work.
- [x] The `cs.zsh` project-name helper still works for Claude.

### Outcome 3: Kimi state persists across container runs

Tests:
- [x] A `kimi-config` volume is created and mounted at `/root/.kimi`.
- [x] `KIMI_API_KEY` (and related env vars) are forwarded when set on the host.
