# OODA Worktree Layout -- Delta

## ADDED: Per-product directory

A product is represented by a single directory that contains the main clone and
all worktrees:

```text
<projects-root>/<product>/
├── main/          # normal clone on the main branch
├── ooda/          # worktree on the orphan ooda branch (control plane)
├── foo/           # feature/foo branch -- loop foo product worktree
└── bar-fix/       # feature/bar-fix branch -- loop bar-fix product worktree
```

## ADDED: Control plane location

Loop definitions, backlog, and archived loops live on the `ooda` branch under:

```text
<product>/ooda/
├── backlog.md
├── <loop-name>/
│   ├── README.md
│   └── archived.md
```

## ADDED: Product worktrees

Each loop drives a dedicated product worktree named for the loop. The worktree
checks out a feature branch branched from `main`.

## ADDED: Sandbox mounting rule

When `cs` is launched from a worktree inside `<product>/`, the container mounts:

- the **sandbox worktree** (the worktree `cs` was launched from) at `/work`;
- `<product>/main/` at its host absolute path (shared `.git` metadata);
- `<product>/ooda/` at its host absolute path (control plane for `/orient`).

Other product worktrees are not mounted: one container session = one loop.

Outside the sandbox, all worktrees are equally accessible on the host; the
sandbox worktree is only meaningful inside the container session.
