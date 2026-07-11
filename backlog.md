# Backlog

Durable observations and cross-loop triggers for the sandbox product.

## Observations

- `cs kimi` overwrites the project-name terminal title set by the launcher; Kimi
  has no equivalent to Claude's `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`. Possible
  fix: filter OSC 0/2 escape sequences out of Kimi's stdout.
- Kimi Code CLI needs `auth.kimi.com`, `api.kimi.com`, and `models.dev` in the
  egress allowlist for OAuth, API calls, and provider catalog lookup. Added to
  the global allowlist in PR #3.

## Triggers

None yet.
