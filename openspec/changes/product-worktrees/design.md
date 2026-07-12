# Design: Product Worktrees

## Host layout

The user chooses a projects root (default `~/work/`). Each product is a
directory under that root:

```text
~/work/
└── musters/
    ├── main/          # normal clone; branch main
    ├── ooda/          # git worktree add ../ooda ooda
    ├── foo/           # git worktree add ../foo -b feature/foo
    └── bar-fix/       # git worktree add ../bar-fix -b feature/bar-fix
```

`main/` is created by `git clone`. `ooda/` and loop worktrees are created with
`git worktree add`. Loop docs live on the `ooda` branch; product code lives on
the feature branch in the loop worktree.

## Skill changes (augment repo)

`ooda.md`:

- Replace the warehouse diagram with the per-product directory layout.
- Define `<product>/main/`, `<product>/ooda/`, and `<product>/<loop>/`.
- Keep direct-push-to-ooda and re-authoring rules unchanged.

`orient.md`:

`/orient` is the skill agents use to load context from active loops. If the
control plane moves from `<product>.warehouse/ooda/` to `<product>/ooda/`, the
skill must know where to look or `/orient` will fail inside the container.

- Update discovery: given a directory, detect whether it is inside a product
  directory; if so, use `<product>/ooda/` as the control plane.
- Update the cross-product registry path to match the new layout, so products
  registered in `ooda-roots` point at their per-product directories.

## Sandbox changes (sandbox repo)

`cs` launcher:

- Remove `CLAUDE_SANDBOX_WAREHOUSE_ROOT` and warehouse detection.
- Accept an optional `--worktree <name>` argument. When given, the sandbox
  worktree is `<product>/<name>/` instead of the directory `cs` was launched
  from.
- Detect whether the sandbox worktree is a Git worktree of a repo that has an
  `ooda` sibling worktree.
- If yes:
  - mount the sandbox worktree at `/work`;
  - mount `<product>/main/` at its host absolute path;
  - mount `<product>/ooda/` at its host absolute path;
  - set the container working directory to `/work`.
- If no `ooda` worktree exists, fall back to the existing `/work` mount.
- Strip `--worktree <name>` from the arguments passed to Claude or Kimi.

`cs.zsh` wrapper:

- `cs <product>` -> `cd <projects-root>/<product>/main`, then run launcher.
- `cs <product> <loop>` -> `cd <projects-root>/<product>/<loop>` if it exists,
  else error.
- `cs <product> --worktree <loop>` -> same as above, for users who prefer the
  explicit switch.
- Keep `cs shell` and `cs rebuild` behaviour unchanged.

`README.md`:

- Replace warehouse-mode docs with the per-product worktree layout.
- Document the projects root override (`CS_PROJECT_ROOT`).

## Container git behaviour

Because `main/` and `ooda/` are mounted at their host absolute paths, Git
worktree metadata resolves correctly. `git worktree list` inside the container
shows `main`, `ooda`, and the sandbox worktree. `/orient` can read the `ooda/`
directory directly.
