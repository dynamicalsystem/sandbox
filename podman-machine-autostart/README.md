---
loop: podman-machine-autostart
product: sandbox
owner: dynamicalsystem
status: Act
parent: null
blocked-by: []
worktrees:
  - /Users/dynamicalsystem/work/sandbox/podman-machine-autostart
prs: []
triggers: []
---

# Podman machine autostart on macOS

## Status

Act

**Owner:** dynamicalsystem

## Context

On macOS, Podman runs inside a virtual machine managed by `podman machine`. When the VM is stopped, attempts to build or run containers fail with a connection-refused error on the Podman socket. The existing `install.sh` warns if Podman is missing but does nothing to keep the VM alive across login sessions.

## Observations

- `podman machine list` showed `podman-machine-default` existed but was stopped.
- Starting the machine manually restored connectivity.
- There is no built-in Podman setting to auto-start the VM on macOS login.
- The standard macOS mechanism for auto-starting a user process at login is a `launchd` LaunchAgent.
- The sandbox installer already performs host-level setup on macOS: symlinking `cs` into `~/.local/bin` and sourcing `cs.zsh` from `~/.zshrc`.

## Orientation

A LaunchAgent that runs `podman machine start` at login is the idiomatic macOS solution. It should be installed by the sandbox installer so the setup is reproducible, but it should be opt-out because it keeps a VM running in the background. Putting the LaunchAgent logic in a separate script keeps `install.sh` readable and makes the host-integration step testable in isolation.

## Decision

Add a macOS-only LaunchAgent installer script and invoke it from `install.sh`:

1. Create `scripts/install-podman-launchagent.sh` that writes `~/Library/LaunchAgents/com.podman.machine.start.plist` and loads it with `launchctl`.
2. Call the script from `install.sh` on macOS unless `SANDBOX_SKIP_PODMAN_LAUNCHAGENT=1`.
3. Document the new behavior and opt-out in `README.md`.

## Action

- Create loop README in the `ooda` control plane.
- Create a `podman-machine-autostart` product worktree from `main`.
- Implement `scripts/install-podman-launchagent.sh` in the product worktree.
- Patch `install.sh` to call the new script on macOS with an opt-out.
- Patch `README.md` to document the LaunchAgent and opt-out.
- Test locally and commit.
- Open a PR promoting the changes to `main`.

## Outcomes

### Outcome 1: macOS installs auto-start the Podman machine at login

Tests:
- [ ] `install.sh` writes `~/Library/LaunchAgents/com.podman.machine.start.plist` on macOS.
- [ ] `launchctl list` shows the agent loaded after install.
- [ ] The Podman machine is running after install (or already running).

### Outcome 2: Users can opt out of the LaunchAgent

Tests:
- [ ] `SANDBOX_SKIP_PODMAN_LAUNCHAGENT=1 ./install.sh` does not write or load the LaunchAgent.

### Outcome 3: Linux and Windows installers are unaffected

Tests:
- [ ] `scripts/install-podman-launchagent.sh` exits silently on non-Darwin systems.
