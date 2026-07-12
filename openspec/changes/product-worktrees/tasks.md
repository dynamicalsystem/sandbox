# Tasks: Product Worktrees

## 1. Update OODA skill

- [x] 1.1 Replace warehouse diagram in `augment/skills/ooda.md` with per-product
      directory layout.
- [x] 1.2 Remove references to `$XDG_DATA_HOME/dynamicalsystem/warehouse` and
      `<project>.warehouse`.
- [x] 1.3 Document `<product>/main/`, `<product>/ooda/`, and `<product>/<loop>/`.
- [x] 1.4 Update `augment/skills/orient.md` discovery rules and registry path.
- [x] 1.5 Commit and push skill changes to the augment repo.

## 2. Revert warehouse logic in sandbox

- [x] 2.1 Remove `CLAUDE_SANDBOX_WAREHOUSE_ROOT` and `XDG_DATA_HOME` handling
      from `cs`.
- [x] 2.2 Remove warehouse detection and the `sandbox.warehouse` fallback.
- [x] 2.3 Remove warehouse-mode section from `README.md` and env-var table
      entries.
- [x] 2.4 Keep the existing `/work` fallback for non-OODA projects.

## 3. Implement product-worktree mounting

- [x] 3.1 Parse an optional `--worktree <name>` argument in `cs`.
- [x] 3.2 Detect whether the sandbox worktree is a Git worktree whose repo has
      an `ooda` sibling worktree.
- [x] 3.3 Find `<product>/main/` (repo common dir) and `<product>/ooda/`.
- [x] 3.4 Mount the sandbox worktree at `/work`.
- [x] 3.5 Mount `<product>/main/` and `<product>/ooda/` at their host absolute
      paths.
- [x] 3.6 Set container working directory to `/work`.
- [x] 3.7 Strip `--worktree <name>` before forwarding arguments to Claude/Kimi.

## 4. Update `cs.zsh`

- [x] 4.1 `cs <product>` changes into `<projects-root>/<product>/main`.
- [x] 4.2 `cs <product> <loop>` changes into `<projects-root>/<product>/<loop>`.
- [x] 4.3 `cs <product> --worktree <loop>` changes into `<projects-root>/<product>/<loop>`.
- [x] 4.4 Keep agent subcommand handling (`kimi`) unchanged.

## 5. Update README

- [x] 5.1 Document the per-product directory layout.
- [x] 5.2 Document `CS_PROJECT_ROOT` default (`~/work`).
- [x] 5.3 Document that loop worktrees are created with `git worktree add`.

## 6. Test

- [x] 6.1 Create a test product directory with `main/`, `ooda/`, and `foo/`.
- [x] 6.2 `cs <product> shell` from `main/` mounts correctly and can read `ooda/`.
- [x] 6.3 `cs <product> foo shell` from host starts in `foo/` with `ooda/` mounted.
- [x] 6.4 `cs <product> --worktree foo shell` from any directory starts in `foo/`.
- [x] 6.5 `git worktree list` inside the container lists `main`, `ooda`, and `foo`.
- [x] 6.6 `/orient` can read a loop README from `ooda/`.
- [x] 6.7 A project without `ooda/` still mounts at `/work` as before.

## 7. Promote and close

- [x] 7.1 Open a PR with the sandbox changes.
- [x] 7.2 Merge and update the `product-worktrees` loop `prs:` frontmatter.
- [x] 7.3 Archive the `product-worktrees` loop.
- [x] 7.4 Sync OpenSpec delta spec to `openspec/specs/ooda-worktrees/spec.md`.
