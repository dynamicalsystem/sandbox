# sandbox

Run Claude Code in an isolated, **rootless, daemonless** container so it can
work autonomously (`--dangerously-skip-permissions`) without reaching your real
machine. The only host directory it sees is the one you launch it from; the
only network it can reach is an egress allowlist.

Generic and project-agnostic: `cs` mounts whatever directory you run it from.
Same files work on **macOS** (podman `applehv`) and **Windows/WSL2** -- one
Containerfile, one workflow, one mental model.

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
cs shell                 # interactive bash inside the sandbox
cs rebuild               # rebuild the image (after a git pull or script edit)
```

First run builds the image (a few minutes). The current directory is mounted at
`/work`; nothing else of your host is visible. Container is `--rm`, so it is
gone on exit -- only the project files it changed and your auth persist.

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

- **API key** (simplest, headless): `export ANTHROPIC_API_KEY=...` before
  running; `cs` passes it through.
- **Subscription/OAuth**: just run `cs` and log in once. The login persists in
  the `claude-config` named volume (`/root/.claude`), so no re-auth next time.

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
| `CLAUDE_SANDBOX_CONFIG_VOLUME`  | `claude-config` | auth-persistence volume |
| `CLAUDE_SANDBOX_WORKDIR`        | `$PWD` | host dir to mount at `/work` |
| `CLAUDE_SANDBOX_ENGINE`         | `podman` | container engine to drive |

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
