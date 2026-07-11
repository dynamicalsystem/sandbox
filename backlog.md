# Backlog

Durable observations and cross-loop triggers for the sandbox product.

## Observations

- `cs kimi` overwrites the project-name terminal title set by the launcher; Kimi
  has no equivalent to Claude's `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`. Possible
  fix: filter OSC 0/2 escape sequences out of Kimi's stdout.
- Kimi Code CLI needs `auth.kimi.com`, `api.kimi.com`, and `models.dev` in the
  egress allowlist for OAuth, API calls, and provider catalog lookup. Added to
  the global allowlist in PR #3.
- Kimi Code CLI 0.23.5 stores config/credentials under `~/.kimi-code`, not
  `~/.kimi`. The `kimi-config` volume was mounted at the wrong path, so `/login`
  credentials were lost on container exit. Fixed in PR #4.
- Kimi Code CLI does not read `KIMI_API_KEY` from shell env vars. The entrypoint
  now auto-seeds `~/.kimi-code/config.toml` from `KIMI_API_KEY` when no provider
  exists, so `cs kimi` starts authenticated without `/login` or `/provider add`.
  Added in PR #5.
- Host `~/.kimi-code/skills/` and `~/.kimi-code/AGENTS.md` are now shared into the
  container read-only so Kimi loads host-managed skills and global prompt while
  auth/config/session state stays in the `kimi-config` volume. Added in PR #6.
- Kimi Code CLI uses `rg` and `fd`/`fdfind` and tries to bootstrap them over the
  network when missing, which fails against the allowlist. `ripgrep` and
  `fd-find` are now pre-installed in the image. Added in PR #7.
- Container hostname was hard-coded to `claude-sandbox` even when running Kimi.
  Now uses `claude-sandbox` for Claude, `kimi-sandbox` for Kimi, and `sandbox`
  for the shell subcommand. Added in PR #8.

## Triggers

None yet.
