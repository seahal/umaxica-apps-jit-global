# Post-Reboot Audit: Claude Remote Control Readiness (2026-07-20)

## Context

The Linux host (Arch, kernel 7.1.3-arch2-2, rootless Podman 6.0.1, user mslo uid 1000) was rebooted
at 14:02. Goal state: the `core` devcontainer runs `claude remote-control --spawn=same-dir` (or
worktree) persistently so Mac / claude.ai/code / mobile can open sessions without any human TUI
interaction. This audit was read-only; no changes were made.

## Verdict: NOT READY

Authentication, CLI, and outbound connectivity are healthy inside the container, but **no
`claude remote-control` process exists anywhere**, no autostart mechanism for it is configured in
the repo, and the container stack itself only came back after reboot via a manual `devcontainer up`
at 14:16 (evidence: `/tmp/devcontainercli-mslo/...` compose files in container labels;
`podman-restart.service` disabled both system and user; `Linger=no`).

## Confirmed Architecture (verified, not assumed)

- Compose project `umaxica-apps-global-dc` from `compose.yaml` +
  `.devcontainer/compose.override.yml` plus two devcontainer-CLI-generated override files under
  `/tmp/devcontainercli-mslo/`.
- Core container `global-devcontainer-core`, user `global` (uid 1000), workdir
  `/home/global/workspace` (bind of repo root, rw), restart policy `always`, not privileged, private
  PID ns, bridge network, no podman/docker socket mount.
- `devcontainer.json` `overrideCommand: true` — the running container's Entrypoint is the
  devcontainer keep-alive shim (`while sleep 1 ...`), **not** `docker/core/entrypoint.sh`.
  Consequently the in-container sshd (REMOTE_SSHD path for Codex) is NOT running.
- Claude auth: `~/.claude` (rw) and `~/.claude.json` (rw) bind-mounted from host; inside container
  `claude auth status` → loggedIn=true, authMethod=claude.ai, files 0600 owned by global. No
  `ANTHROPIC_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN` env vars set.
- Claude CLI 2.1.215 at `/usr/local/bin/claude`; `claude remote-control --help` confirms `--name`,
  `--spawn same-dir|worktree|session` (default same-dir), `--capacity` (default 32).
- Outbound: DNS resolves api.anthropic.com; TCP 443 reachable from container. (Full TLS check via
  curl blocked by permission rule; TCP+DNS verified.)
- Tailscale up on host (mp4 100.109.188.54; macbook-pro online). Host sshd inactive.
- Codex-in-container process exists (a codex TUI + MCP servers, started ~1h ago from an interactive
  shell) — no Claude remote-control process, container or host.

## Gate Results

| Gate                   | Result           | Evidence                                                                                                              |
| ---------------------- | ---------------- | --------------------------------------------------------------------------------------------------------------------- |
| Rootless Podman        | PASS             | podman 6.0.1 rootless, user systemd healthy, 0 failed units                                                           |
| Compose config         | PASS (with note) | stack resolved & running; rustfs service crash-looping (`OBJECT_STORAGE_ACCESS_KEY_ID must be set`) — unrelated to RC |
| Core container         | PASS             | Up ~1h, healthy deps, correct user/mounts                                                                             |
| Claude CLI             | PASS             | 2.1.215 in PATH as `global`                                                                                           |
| Claude authentication  | PASS             | loggedIn=true, claude.ai subscription, 0600 perms, persists via host bind mounts                                      |
| Remote Control process | FAIL             | `ps` in container + host: no remote-control process                                                                   |
| Automatic startup      | FAIL             | nothing in compose/entrypoint/devcontainer lifecycle/systemd starts remote-control; grep found zero wiring            |
| Reboot recovery        | FAIL             | containers restored only by manual `devcontainer up` at 14:16; podman-restart.service disabled, Linger=no             |
| Secret persistence     | PASS             | auth lives on host FS, survives container recreation; not baked into image                                            |
| Host isolation         | PASS             | non-privileged, no host PID/net, no podman.sock/docker.sock mount; ~/.ssh mounted read-only                           |
| Outbound connectivity  | PASS             | DNS + TCP 443 to api.anthropic.com from container                                                                     |
| Mac-side visibility    | UNKNOWN          | requires Mac-side check (nothing to see yet — process not running)                                                    |

## Findings

**Critical**

1. Remote Control is not running and has no autostart. Impact: primary goal unmet; Mac sees nothing.
   Fixable later: yes. Fix: see plan below.
2. No reboot-time auto-start of the compose stack (restart:always is inert under rootless Podman
   without `systemctl --user enable podman-restart` + `loginctl enable-linger mslo`). Currently a
   human must run devcontainer/compose up after each reboot.

**High** 3. `overrideCommand: true` suppresses `docker/core/entrypoint.sh`, so tmpfs chown
normalization and the REMOTE_SSHD sshd block never run in devcontainer mode. The Codex Remote SSH
path is configured (volumes, keys, docs) but currently dead. Also means any future RC autostart must
NOT be placed in that entrypoint alone.

**Medium** 4. rustfs crash-loop: entrypoint requires `OBJECT_STORAGE_ACCESS_KEY_ID`, not provided.
Unrelated to RC; breaks object-storage-dependent dev flows. 5. Same-dir spawn shares one worktree
across up to 32 concurrent remote sessions plus the local codex TUI already running in the same
checkout — concurrent-edit collisions are possible. Mitigate with `--spawn=worktree` or accept with
capacity awareness.

**Low / Informational** 6. Podman API socket active on host (user scope) but not mounted anywhere —
fine. 7. Stale exited container `umaxica-apps-edge-dc-core-1` (47h) — harmless.

## Irreversibility Review

No irreversible traps found. Auth state lives on the host filesystem (not in volumes or image
layers); UID mapping (host 1000 → container global 1000, `updateRemoteUserUID:false`) is consistent;
all fixes below are additive and reversible. 該当なし beyond that.

## Required Fix Plan (not executed — awaiting approval)

1. **Add an RC supervisor script** `docker/core/start-remote-control.sh` (new file): idempotent
   (checks for an existing `claude remote-control` pid), runs as `global` in
   `/home/global/workspace`, logs to `~/.cache/claude-remote-control.log`, e.g.
   `claude remote-control --name "Umaxica Rails" --spawn=worktree` (worktree recommended given the
   shared checkout; user to confirm spawn mode), wrapped in a restart loop
   (`until ...; do sleep 5; done`) for crash recovery. Rollback: delete file + hook. Verify:
   `podman exec ... pgrep -af remote-control`.
2. **Wire it into the devcontainer lifecycle**: add `"postStartCommand"` in
   `.devcontainer/devcontainer.json` invoking the script with `nohup ... &` (runs on every container
   start, survives VS Code detach because the process is parented to PID 1's namespace, not the VS
   Code server). This works even with `overrideCommand: true`.
3. **Reboot autostart (host)**: `loginctl enable-linger mslo` and
   `systemctl --user enable --now podman-restart.service` so restart:always containers return after
   reboot without login. Note: postStartCommand only fires via devcontainer CLI, so pair this with
   either (a) accepting "run `devcontainer up` after reboot" as the documented manual step, or (b)
   moving RC startup into a compose-visible path (e.g. a small `command:` wrapper) — decide in
   implementation.
4. **Restore entrypoint behavior under devcontainer** (fixes sshd/Codex path): either set
   `"overrideCommand": false` (compose entrypoint already ends in a keep-alive-compatible
   `exec "$@"` — needs a keep-alive command) or invoke `docker/core/entrypoint.sh` logic from
   postStartCommand. Risk: container start ordering; verify sshd via `pgrep -a sshd` in container
   and Tailscale SSH from Mac.
5. **rustfs**: provide `OBJECT_STORAGE_ACCESS_KEY_ID`/secret via env file (separate task).

## Manual Mac Gate (after fixes)

1. claude.ai/code (or mobile) lists a Remote Control named "Umaxica Rails".
2. Create a new session from the Mac; confirm it spawns.
3. In that session run `pwd` — expect `/home/global/workspace` (or a worktree path).
4. Run a read-only command (`git status`) successfully.
5. On Linux: `podman exec global-devcontainer-core pgrep -af claude` and the RC log show the
   matching session.

## Final Recommendation

利用開始前に修正が必要 (fixes required before use). No changes were made during this audit.
