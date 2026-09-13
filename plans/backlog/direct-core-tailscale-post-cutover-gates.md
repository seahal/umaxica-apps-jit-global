# Direct-Core Tailscale Post-Cutover Gates

## Status

- Gate 1: **Completed on 2026-07-22**
- Gate 2: **Deferred and optional**
- Gate 3: **Not started; blocked on an explicit cleanup decision**

This backlog item records validation and cleanup work that may never be scheduled. It does not
change the current operating architecture.

Current behavior and operator commands are documented in
`docs/operations/remote-codex-over-tailscale.md`. Implementation evidence and known limitations are
recorded in `notes/implementation/2026-07-22-core-tailscale-ssh-userspace-poc.md`.

## Gate 1 completion record

The development-only `core` image now runs userspace `tailscaled` alongside the normal `bin/dev`
workload. Built-in Tailscale SSH reaches the actual `core` container as `global`, and tailnet-only
HTTPS Serve proxies to Rails on `127.0.0.1:3000`.

The verified properties are:

- no `/dev/net/tun`, added capability, privileged mode, host network, or host TCP port 22;
- external `ssh global@umaxica-global-core` reaches the recreated container;
- `bin/dev` still starts Foreman, Rails, Vite, and Solid Queue;
- the direct node identity and Serve configuration survive rebuild, recreate, and container restart
  through `tailscale-core-state`;
- the legacy `tailscale-codex` container and OpenSSH-over-Tailscale repository configuration are
  removed;
- the independent Cloudflare Tunnel sidecar remains running and unchanged;
- the legacy sidecar state volume and retired Tailnet node are retained only as rollback assets.

## Gate 2: resilience validation

Gate 2 is optional because normal development and direct Tailscale SSH already work. Skipping it
means the risks listed below remain explicitly unverified; it does not invalidate the Gate 1 result.

### Scope

1. Perform a real Arch Linux host reboot and verify the rootless Podman and Dev Container recovery
   sequence.
2. Determine whether `core` is intentionally manual-start or should be restored automatically after
   reboot. Do not enable lingering or a user systemd unit without separate approval.
3. Terminate `tailscaled` deliberately and verify bounded independent restart, degraded status
   reporting, and continued Rails/Vite/jobs/Claude Code use.
4. Test control-plane and authentication failure behavior without exposing or invalidating
   credentials unintentionally.
5. Verify external Tailscale SSH and HTTPS Serve again after the host reboot and injected failures.
6. Diagnose the Rails HTTP 500 that was reproduced both through HTTPS Serve and directly on
   localhost. Treat transport success and application success as separate results.
7. Confirm the exact `TAILSCALE_SERVE_HOST` remains available to future Dev Container recreations
   without committing it as a secret or widening Rails Host Authorization.
8. Evaluate an independent host Tailscale SSH break-glass path. This is a resilience decision, not
   evidence for or against direct placement in `core`.

### Acceptance criteria

- A host reboot has a documented and repeatable recovery path.
- A failed `tailscaled` cannot terminate the healthy development workload.
- The restart budget and degraded status are observable and deterministic.
- The same Tailscale node identity returns after restart and host recovery.
- Direct SSH reaches `core` after recovery.
- HTTPS Serve receives an application-level successful response, or the Rails failure is separately
  diagnosed and accepted.
- No bootstrap credential is added to Compose, image layers, process arguments, logs, or the
  repository.

### If Gate 2 is skipped

Keep the following limitations visible:

- host-reboot recovery is unverified;
- deliberate tailscaled failure and restart-budget behavior are unverified;
- no independent host break-glass path exists;
- Rails currently returns HTTP 500 on the tested local and Serve HTTP paths;
- rollback assets must not be deleted merely because ordinary restart and recreate tests passed.

## Gate 3: operational finalization and cleanup

Gate 3 is destructive and must not run implicitly. It requires explicit user approval for each
external Tailnet or local Podman deletion. Gate 2 completion is preferred but not mandatory; if Gate
2 is skipped, the user must explicitly accept the remaining recovery risk first.

### Scope

1. Confirm the rollback window is closed.
2. Remove the retired Tailnet machine `umaxica-global-core-sidecar-retired` from the Tailscale admin
   console.
3. Delete the retained `tailscale-codex-state` Podman volume only after its exact identity and lack
   of other consumers are verified.
4. Remove or revoke any obsolete Tailscale auth key that remains in local configuration, without
   printing it.
5. Rotate the previously exposed Cloudflare Tunnel token and verify the existing Cloudflare sidecar
   reconnects with the replacement token.
6. Review Tailscale grants and SSH rules for least privilege, avoiding broad all-user or all-host
   access.
7. Record Mac and iPhone loss/revocation procedures and the final recovery route when `core` is
   down.
8. Re-run production-stage isolation checks and confirm neither Tailscale nor development SSH
   components appear in the production image.

### Acceptance criteria

- No obsolete Tailscale sidecar container, node, state volume, auth key, Serve configuration, or
  OpenSSH server path remains.
- The direct node retains the single official name `umaxica-global-core`.
- Cloudflare Tunnel continues its independent Web, Access, and Workers VPC responsibilities after
  token rotation.
- Device-loss revocation and `core`-down recovery are documented.
- Rollback after cleanup is understood to require a new sidecar identity rather than the deleted
  historical state.

## Stop conditions

Stop and report before continuing when any of the following occurs:

- a Tailnet policy is broader than expected;
- a command would print or persist an authentication credential;
- a deletion target cannot be identified exactly;
- the direct node identity changes unexpectedly;
- Cloudflare Tunnel health changes during Tailscale-only work;
- a failure test threatens unrelated development processes or data.

## Rollback assets currently retained

- Tailnet machine: `umaxica-global-core-sidecar-retired`
- Podman volume: `umaxica-apps-global-dc_tailscale-codex-state`

Their presence is intentional until Gate 3 is explicitly approved. Do not interpret them as active
services or delete them as generic orphan cleanup.
