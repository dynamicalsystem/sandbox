# Project: sandbox

Run Claude Code and Kimi Code inside a rootless, egress-restricted container.

This repo also pilots the OODA/augment integration: the control plane for a
product lives in an `ooda` orphan-branch worktree, and the sandbox must make that
control plane visible to the agent while keeping product changes isolated per
loop.
