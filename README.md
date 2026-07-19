# sandbox

Run Claude Code in an isolated, **rootless, daemonless** container so it can
work autonomously (`--dangerously-skip-permissions`) without reaching your real
machine. The only host directory it sees is the one you launch it from; the
only network it can reach is an egress allowlist.

Generic and project-agnostic: `cs` mounts whatever directory you run it from.
It also understands the OODA per-product worktree layout. Same files work on
**macOS** (podman `applehv`) and **Windows/WSL2** -- one Containerfile, one
workflow, one mental model.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/dynamicalsystem/sandbox/main/install.sh | bash
```

This clones the repo to `~/.local/share/sandbox` and symlinks `cs` into
`~/.local/bin`. Needs `podman` and (the first time) a running machine:

```bash
podman machine init && podman machine start    # once, if you have no machine
```

From a local checkout instead: `./install.sh`.

## Use

```bash
cd ~/some/project        # the dir Claude will be able to see
cs                       # claude --dangerously-skip-permissions, sandboxed
cs --version             # args pass straight through to claude
cs kimi                  # kimi --yolo, sandboxed (Kimi Code CLI)
cs kimi --version        # args pass straight through to kimi
cs shell                 # interactive bash inside the sandbox
cs rebuild               # rebuild the image (after a git pull or script edit)
```

First run builds the image (a few minutes). The current directory is mounted at
`/work`; nothing else of your host is visible. Container is `--rm`, so it is
gone on exit -- only the project files it changed and your auth persist.

### Jump straight into a project

`install.sh` also drops a `cs()` shell function into your `~/.zshrc` (sourced
from `cs.zsh`). Give it a project name and it `cd`s into that project's
per-product directory before launching the sandbox:

```bash
cs myproj             # cd ~/work/myproj/ooda, then sandbox it
                      # (falls back to ~/work/myproj/main if there is no ooda/)
cs myproj foo         # cd ~/work/myproj/foo, then sandbox it
                      # (if foo doesn't exist, you'll be asked to create it)
cs myproj main        # cd ~/work/myproj/main, then sandbox it
cs myproj --worktree foo  # explicit form of `cs myproj foo`
cs kimi myproj foo    # cd ~/work/myproj/foo, then launch Kimi
cs myproj --resume    # cd into the default worktree, pass --resume to claude
cs                    # no name -> sandbox in $PWD, exactly as before
cs shell / cs rebuild # subcommands still work, run in $PWD
```

For an OODA product the no-loop form lands in the control plane, so bare
`cs myproj` and `cs myproj ooda` are equivalent. Loop-scoped work names its
worktree (`cs myproj foo`); orientation sessions get the `ooda/` worktree by
default.

Override the projects root with `CS_PROJECT_ROOT` (default `~/work`). The
function calls the launcher via `command cs`, so the bare-`cs` behaviour above
is unchanged.

### OODA worktrees

If a product is laid out as a directory of worktrees, `cs` detects it and mounts
the right pieces into the container:

```text
~/work/<product>/
├── main/          # normal clone, main branch
├── ooda/          # control-plane worktree on the orphan ooda branch
├── foo/           # loop foo product worktree
└── bar-fix/       # loop bar-fix product worktree
```

The container mounts:

- the sandbox worktree (the one you launched from, or the one named by
  `--worktree`) at `/work`;
- `<product>/main/` at its host absolute path, so Git metadata resolves;
- `<product>/ooda/` at its host absolute path, so `/orient` can read loop docs.

This lets `git worktree list` inside the container see `main`, `ooda`, and the
sandbox worktree, while keeping each container session scoped to a single loop.

If you name a loop worktree that does not exist yet, `cs.zsh` asks whether to
create it. Confirming adds the Git worktree from `main/` and creates a skeleton
`ooda/<loop>/README.md`, then launches the agent in the new worktree. In
non-interactive contexts (stdin not a tty) the wrapper keeps the old error
behavior so scripts do not hang.

## Why this shape

- **Rootless + daemonless** -- Podman fork-execs the container as your
  unprivileged user; no root daemon owns it. "root" inside the container maps to
  you on the host, which is what lets the firewall program iptables *and* keeps
  files written to `/work` owned by you (not a weird subuid).
- **Egress allowlist** -- the firewall is what makes skipping permissions
  defensible, not the container boundary alone. Default-deny outbound; only the
  allowlisted domains are reachable.
- **Isolation is from the host, not between agents.** Two `cs` sessions share
  the podman-machine kernel -- fine, since the threat model is "keep Claude off
  my laptop", which the VM boundary already covers. Separate kernels would mean
  separate podman machines; you do not need that here.

## Auth

Pick one:

- **Subscription OAuth token** (recommended): mint a long-lived (~1 year) token
  once on the host and forward it, exactly like `GH_TOKEN`. No volume state, no
  re-auth, survives `--rm`:

  ```bash
  claude setup-token          # prints a sk-ant-oat... token (needs a subscription)
  printf 'CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat...\n' >> ~/.config/dynamicalsystem/sandbox
  ```

  `cs` forwards `CLAUDE_CODE_OAUTH_TOKEN` into the container, so every launch is
  authenticated with zero web-OAuth roundtrip. (Don't have `claude` on the host?
  Run `cs shell` once, run `claude setup-token` inside, copy the token out.)
- **API key** (simplest, headless): `export ANTHROPIC_API_KEY=...` before
  running; `cs` passes it through.

Both are forwarded the same stateless way as the GitHub token -- the secret
stays in the host-side file (`~/.config/dynamicalsystem/sandbox`) and is handed
in as an env var, so nothing auth-related needs to persist in the volume.

> **Why not just log in interactively?** An interactive `claude` login writes the
> OAuth *account record* to `/root/.claude.json` (at `$HOME`, **outside** the
> `claude-config` volume). Claude Code rewrites that file atomically (`rename()`),
> which defeats any symlink-into-the-volume trick, so on a `--rm` container the
> account record is dropped and you get the web-OAuth prompt **every launch** --
> even though the credentials file persisted. The forwarded token sidesteps all
> of this. If you want interactive login to stick instead, mount the volume at
> `/root` rather than `/root/.claude` so `.claude.json` lands in it for real.

### Kimi auth

Kimi Code CLI does not read API keys from shell environment variables directly.
To avoid running `/login` or `/provider add` every launch, add a Kimi API key to
the same host-side env file:

```bash
printf 'KIMI_API_KEY=sk-kimi-xxx\n' >> ~/.config/dynamicalsystem/sandbox
```

The entrypoint auto-seeds `~/.kimi-code/config.toml` from `KIMI_API_KEY` on the
first run (or if the config has no provider), so `cs kimi` starts already
authenticated. Set `KIMI_BASE_URL` if you use a custom endpoint.

### Kimi skills and AGENTS.md

Host-managed Kimi skills and a global `AGENTS.md` are shared into the container
read-only while auth/config/session state stays in the `kimi-config` volume:

```bash
mkdir -p ~/.kimi-code/skills
ln -s ~/Documents/dynamicalsystem/augment/<github-username>-AGENTS.md ~/.kimi-code/AGENTS.md
```

`cs kimi` bind mounts `~/.kimi-code/skills/` to `/root/.kimi-code/skills/` and
`~/.kimi-code/AGENTS.md` to `/root/.kimi-code/AGENTS.md` when they exist. Set
`KIMI_HOST_DIR` to override the host path.

### Pushing to GitHub

The sandbox pushes over **HTTPS with a token** -- no ssh key is ever exposed to
the agent. Give it a **fine-grained PAT** scoped to just the repos you want
(`Contents: RW`, `Pull requests: RW`), so even a misbehaving agent can't reach
the rest of your account. Put it in an untracked host-side file:

```bash
mkdir -p ~/.config/dynamicalsystem
printf 'GH_TOKEN=github_pat_xxx\n' > ~/.config/dynamicalsystem/sandbox
chmod 600 ~/.config/dynamicalsystem/sandbox
```

`cs` *sources* that file and forwards `GH_TOKEN` (and `GITHUB_TOKEN`); the
entrypoint runs `gh auth setup-git`, so `git push` and `gh pr create` just work.
Git author identity is read from your host `git config` automatically (override
with `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL` in the same file). It is a shell file,
so **quote any value with spaces** -- `GIT_AUTHOR_NAME="Ada Lovelace"`.

Because the file is *sourced*, the token can also be **minted per run** rather
than stored -- point `GH_TOKEN` at a command:

```bash
# ~/.config/dynamicalsystem/sandbox -- mint a short-lived GitHub App
# installation token on the host; the App private key never enters the sandbox.
GH_TOKEN=$(my-app-token-minter)
```

GitHub App installation tokens (`POST /app/installations/{id}/access_tokens`)
expire in an hour and are repo-scoped, so a leak self-heals -- the only API path
to programmatically *renew* a credential (personal fine-grained PATs can only be
created/regenerated in the web UI). The sandbox is indifferent: it just consumes
`GH_TOKEN`. Either way, `cs rebuild` is needed once to pick up `gh` in the image.

## Allowlist

Two layers, merged at container start:

- **Global** (`allowed-domains.txt` in this repo): project-neutral essentials --
  Anthropic, npm, GitHub.
- **Per-project** (`.claude-sandbox/allowed-domains.txt` inside a project): extra
  domains just that project needs. `cs` mounts it automatically when present, so
  project-specific access never pollutes the global list.

Both are plain `domain-per-line` files (`#` comments allowed). Edits apply on the
next `cs` run -- no rebuild. If something Claude needs hangs on a network call,
that is the allowlist; add the domain and restart.

## Two agents at once

```bash
cd ~/projectA && cs      # window 1
cd ~/projectB && cs      # window 2
```

Two containers, two fresh firewalls, each pinned to its own mounted dir. They
share the machine kernel but cannot see each other's files.

## Knobs (env vars)

| Var | Default | Effect |
|-----|---------|--------|
| `CLAUDE_SANDBOX_FIREWALL`       | `1` | set `0` to disable the egress allowlist |
| `CLAUDE_SANDBOX_IMAGE`          | `claude-sandbox:latest` | image tag |
| `CLAUDE_SANDBOX_CONFIG_VOLUME`      | `claude-config` | Claude auth-persistence volume |
| `CLAUDE_SANDBOX_KIMI_CONFIG_VOLUME` | `kimi-config` | Kimi auth-persistence volume (mounted at `/root/.kimi-code`) |
| `KIMI_HOST_DIR`                     | `~/.kimi-code` | host path for Kimi skills/AGENTS.md bind mounts |
| `CS_PROJECT_ROOT`                   | `~/work` | directory that holds per-product directories |
| `CLAUDE_SANDBOX_WORKDIR`            | `$PWD` | host dir to mount at `/work` (fallback for non-OODA projects) |
| `CLAUDE_SANDBOX_ENGINE`         | `podman` | container engine to drive |
| `CLAUDE_SANDBOX_ENV`            | `~/.config/dynamicalsystem/sandbox` | host file sourced for `GH_TOKEN` / `CLAUDE_CODE_OAUTH_TOKEN` / git identity (a directory with an `env` file inside also works) |

Installer knobs: `SANDBOX_HOME`, `SANDBOX_REPO`, `PREFIX` (see `install.sh`).

## Windows / WSL2

Run the same `cs` from a WSL2 shell (where podman lives). The isolation boundary
there is WSL2's own VM rather than bare Win32, and the host path is the WSL2
filesystem -- the Podman CLI papers over the difference, rootless holds on both.
Keep the project on the WSL2 side (`~/...`, not `/mnt/c/...`) for sane file
performance.

## Caveats

- **No ipset.** The podman-machine kernel ships no `ipset`/`xt_set` module, so
  the firewall uses plain per-IP iptables rules. If you ever lift Anthropic's
  devcontainer firewall verbatim, it will not work here as-is.
- **Rebuild after editing baked files.** `Containerfile`, `init-firewall.sh`,
  and `entrypoint.sh` are baked into the image; `cs` only auto-builds when the
  image is *absent*, so after editing them (or `git pull`) run `cs rebuild` or
  you will silently run a stale image. Allowlist edits are mounted -- no rebuild.
- **Firewall fail-closed.** If iptables setup fails partway, egress ends up
  blocked, not open -- but the entrypoint's warning text may read "NOT
  restricted". If you see that warning, treat the network state as untrusted and
  investigate rather than believing either reading.
- **Allowlist resolved once at startup.** Long sessions can outlive a CDN's DNS;
  if a previously-working host starts failing, restart the container.
