# Sudo-less Development Workspace Implementation Notes

## Context

- Original plan: the accepted conversation plan for `development`, `workspace`, and `production`
  Dockerfile outcomes.
- Related documentation: `docs/operations/development-container-targets.md` and
  `docs/operations/remote-codex-over-tailscale.md`.
- Implementation date: 2026-07-27.

## Decisions Made During Implementation

- Keep a root PID 1 for fixed tmpfs initialization and the direct-core Tailscale daemon, but launch
  every development workload as `global` through `setpriv`.
  - This preserves Tailscale SSH user switching while removing general-purpose passwordless
    elevation from Rails and coding agents.
- Install the entrypoint, supervisor, status command, and login profile as root-owned image files.
  - A root process must not execute or source the bind-mounted workspace, even when the current Dev
    Container mount is read-only.
- Reject symlinked runtime directories before root changes ownership.
  - `tmp` and `log` live under a writable workspace, so a fixed path alone does not prevent a
    symlink-redirection attack across container restarts.
- Copy the filtered PID 1 environment into an owner-only file under `/run`.
  - Once PID 1 is root, a `global` Tailscale SSH login cannot read `/proc/1/environ` directly. The
    runtime file preserves the existing remote-shell environment without weakening procfs
    permissions.
- Preserve the already-staged workload restart/backoff behavior in the Tailscale supervisor.

## Review Notes

- Passed: shell syntax, non-root fail-closed checks, Ruby syntax, static target/security assertions,
  normal Compose rendering, workspace Compose rendering, and `git diff --check`.
- Blocked: the focused Rails test cannot boot because the locked Rails git dependency is not checked
  out under `vendor/bundle`.
- Blocked: image build and runtime checks because the current session cannot access the Docker
  socket, while Podman cannot initialize its runtime directory on the read-only host mount.
- Not performed: recreation of the persistent `core` container, Tailscale state changes, Tailnet
  policy changes, or Podman Secret migration.
