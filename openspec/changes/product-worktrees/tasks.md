# Tasks: Product Worktrees

## 1. Update OODA skill

- [ ] 1.1 Replace warehouse diagram in `augment/skills/ooda.md` with per-product
      directory layout.
- [ ] 1.2 Remove references to `$XDG_DATA_HOME/dynamicalsystem/warehouse` and
      `<project>.warehouse`.
- [ ] 1.3 Document `<product>/main/`, `<product>/ooda/`, and `<product>/<loop>/`.
- [ ] 1.4 Update `augment/skills/orient.md` discovery rules and registry path.
- [ ] 1.5 Commit and push skill changes to the augment repo.

## 2. Revert warehouse logic in sandbox

- [ ] 2.1 Remove `CLAUDE_SANDBOX_WAREHOUSE_ROOT` and `XDG_DATA_HOME` handling
      from `cs`.
- [ ] 2.2 Remove warehouse detection and the `sandbox.warehouse` fallback.
- [ ] 2.3 Remove warehouse-mode section from `README.md` and env-var table
      entries.
- [ ] 2.4 Keep the existing `/work` fallback for non-OODA projects.

## 3. Implement product-worktree mounting

- [ ] 3.1 Detect whether the launch directory is a Git worktree whose repo has
      an `ooda` sibling worktree.
- [ ] 3.2 Find `<product>/main/` (repo common dir) and `<product>/ooda/`.
- [ ] 3.3 Mount the sandbox worktree at `/work`.
- [ ] 3.4 Mount `<product>/main/` and `<product>/ooda/` at their host absolute
      paths.
- [ ] 3.5 Set container working directory to `/work`.

## 4. Update `cs.zsh`

- [ ] 4.1 `cs <product>` changes into `<projects-root>/<product>/main`.
- [ ] 4.2 `cs <product> <loop>` changes into `<projects-root>/<product>/<loop>`.
- [ ] 4.3 Keep agent subcommand handling (`kimi`) unchanged.

## 5. Update README

- [ ] 5.1 Document the per-product directory layout.
- [ ] 5.2 Document `CS_PROJECT_ROOT` default (`~/work`).
- [ ] 5.3 Document that loop worktrees are created with `git worktree add`.

## 6. Test

- [ ] 6.1 Create a test product directory with `main/`, `ooda/`, and `foo/`.
- [ ] 6.2 `cs <product> shell` from `main/` mounts correctly and can read `ooda/`.
- [ ] 6.3 `cs <product> foo shell` from host starts in `foo/` with `ooda/` mounted.
- [ ] 6.4 `git worktree list` inside the container lists `main`, `ooda`, and `foo`.
- [ ] 6.5 `/orient` can read a loop README from `ooda/`.
- [ ] 6.6 A project without `ooda/` still mounts at `/work` as before.

## 7. Promote and close

- [ ] 7.1 Open a PR with the sandbox changes.
- [ ] 7.2 Merge and update the `product-worktrees` loop `prs:` frontmatter.
- [ ] 7.3 Archive the `product-worktrees` loop.
- [ ] 7.4 Sync OpenSpec delta spec to `openspec/specs/ooda-worktrees/spec.md`.
