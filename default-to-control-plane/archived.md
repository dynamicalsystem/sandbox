# Archived

- **Closed**: 2026-08-07 14:07 UTC
- **Status**: Succeeded
- **Summary**: `cs <project>` (bare, agent-prefixed, flag-only, and `shell`
  forms) now defaults to the `ooda/` control-plane worktree when it exists,
  falling back to `main/` for non-OODA products. `cs <project> main` remains
  the explicit route to the main worktree. Merged in PR #16.
- **Outcomes**: 6/6 tests passed (16 checks across zsh and bash).
- **Follow-up**: None.
