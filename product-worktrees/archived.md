# Archived

- **Closed**: 2026-07-12 11:40 UTC
- **Status**: Succeeded
- **Summary**: Moved from a bare-repo warehouse to a per-product directory of
  Git worktrees. The sandbox now mounts a single loop worktree as `/work`, plus
  `main/` and `ooda/` at their host absolute paths, so `git worktree list` and
  `/orient` work inside the container.
- **Outcomes**: 8/8 tests passed.
- **Follow-up**: None.
