# Gate A Report — Remote Codex over Tailscale into the `core` dev container

Date: 2026-07-19. Read-only investigation only; no files changed yet. Supersedes the file layout in
`plans/grill-me-with-crystalline-quill.md` where the two differ (notably: **no
`compose.remote.yml`** — implementation goes into `compose.yaml` +
`.devcontainer/compose.override.yml` per the current instruction).

## 1. Current state

- Rails app repo, dev environment = rootless Podman compose project `umaxica-apps-global`
  (devcontainer project `umaxica-apps-global-dc`, container `global-devcontainer-core`).
- `core` service: `build:` from `./Dockerfile` (no `target:` → final stage `development` is built),
  `entrypoint: docker/core/entrypoint.sh`, `command: ["bin/dev"]`, `restart: always`, inline
  `environment:` only (no `env_file:` anywhere in the repo), tmpfs for tmp/log dirs, 4 named
  home/deps volumes, **no healthcheck, no host ports in base compose**.
- `core` networks: `backend`, `frontend` (large `*.localhost`/`*.umaxica.*` alias list),
  `observability`, `outer` (alias `global`). Top-level networks are plain bridges; only `outer` is
  name/external-parameterized. No `internal:` flag used anywhere.
- `cloudflare-tunnel` is the existing infra-sidecar precedent: pinned `image:`, `depends_on: core`,
  inline `environment:` with `${VAR}` interpolation from untracked root `.env`, single network
  (`frontend`), `extra_hosts: host.docker.internal:host-gateway`, `restart: unless-stopped`, no
  profile.
- `.devcontainer/compose.override.yml`: `userns_mode: keep-id`, `user: !reset null`, workspace bind
  mount, ports 3000/3036 for core, build args `DOCKER_UID/GID` from `${UID}/${GID}`.
- `.devcontainer/devcontainer.json`: `service: core`, **no `runServices`** (all non-profile services
  start), `remoteUser/containerUser: global`, no lifecycle commands. `~/.codex` mounted **rw**,
  `~/.ssh` mounted **ro**. Codex installed by feature
  `ghcr.io/jsburckhardt/devcontainer-features/codex:1`.
- `docker/core/` contains only `entrypoint.sh` (runs as `global`, `set -euo pipefail`, `sudo chown`
  of tmpfs dirs, then `exec "$@"`) and `preferences/`. No `docker/tailscale/` dir.
- In-container probes: OS Debian 13 (trixie); `codex` = real binary at **`/usr/local/bin/codex`**
  (v0.144.5, not a symlink) → already on sshd's default non-interactive PATH; `socat` present at
  `/usr/bin/socat`; **no sshd installed**; `global` uid=1000 gid=1000(umaxica) with working
  passwordless sudo; no TCP listeners currently.

## 2. Confirmed facts

1. `development` is the effective build target for `core`; `production` stage locks root, removes
   sudo — SSH additions to the dev-stage apt block cannot leak into production.
2. Codex needs **no PATH work in the common case**: the binary physically lives in `/usr/local/bin`,
   which is on OpenSSH's default `_PATH_STDPATH`. `SetEnv PATH=...` stays as a documented fallback
   only; verified empirically in Gate D.
3. `socat` is already in the dev image → the sidecar-internal fallback (serve → localhost → socat)
   or a core-side relay is available without new packages.
4. Compose DNS name `core` resolves on shared user-defined networks under netavark/aardvark-dns; no
   static IPs needed.
5. Repo env convention: interpolation from untracked root `.env` + inline `environment:`;
   `env_file:` is unused so far. `~`-style host paths appear only in devcontainer mounts.
6. Prose language policy: English (confirmed with user for the new ops doc).
7. This session runs **inside** the `core` container with no Podman socket → Gate C will be "provide
   exact commands for the user to run on the Linux host", not direct execution.
8. A prior Japanese design plan exists (`plans/grill-me-with-crystalline-quill.md`); its
   architecture (sidecar + `TS_SERVE_CONFIG` TCPForward, SSH terminated in core, socat fallback)
   matches this task and its research findings are reused below.

## 3. Differences from the supplied assumptions

- `~/.ssh` ro mount, `~/.codex` rw mount, keep-id, 4 networks, Debian trixie, apt, dev/production
  stages, passwordless sudo, cloudflare-tunnel precedent — **all confirmed as assumed**.
- `socat` **is** already installed (assumption said "possibly"). `openssh-server`/`openssh-client`
  are **not** installed anywhere (assumption confirmed).
- Codex is installed by a Dev Container **Feature**, but into `/usr/local/bin` directly — no symlink
  or `SetEnv` is expected to be necessary (better than assumed).
- The prior plan proposed `compose.remote.yml` + a compose `profile`; the current instruction
  forbids `compose.remote.yml`, so the layout below follows the instruction.
- `global`'s login group is `umaxica` (gid 1000), not `global` — relevant for file ownership in sshd
  `StrictModes` checks.

## 4. Proposed architecture

```
Mac (manual, out of scope) ──tailnet──▶ tailscale-codex sidecar (userspace, no caps, no host ports)
                                             │  TS_SERVE_CONFIG: TCP 22 → TCPForward "core:22"  [SPIKE]
                                             ▼
                              remote-access network (new, only sidecar + core)
                                             ▼
                              core :22 OpenSSH (dev image only, REMOTE_SSHD=1 gated)
                                             ▼
                              global user, pubkey-only → codex app-server over SSH exec (stdio)
```

- SSH terminates in `core` (user, workspace, toolchains, `~/.codex` all live there).
- Sidecar joins **only** `remote-access`. `remote-access` is a plain bridge (NOT `internal: true`)
  because it is the sidecar's sole network and the sidecar needs outbound reachability to the
  Tailscale control plane / DERP. Making it internal would require also joining the sidecar to
  `frontend` or similar, which widens exposure more than a dedicated egress-capable bridge does.
- Sidecar is defined in base `compose.yaml` like `cloudflare-tunnel` (no profile), pinned image,
  `restart: unless-stopped`. Without an auth key/state it idles logged-out — harmless for other
  checkouts. Its `env_file` uses `required: false` so machines without
  `~/.config/umaxica/tailscale.env` still `compose up` cleanly.
- All SSH enablement on `core` (env var, config mount, key mounts, `remote-access` membership) lives
  in `.devcontainer/compose.override.yml` → base/production-ish usage of `compose.yaml` alone never
  starts sshd in core.

## 5. Proposed file changes

1. **`Dockerfile`** — add `openssh-server` to the existing `development`-stage
   `apt-get install --no-install-recommends` list (alphabetical position; same layer, no new layer).
   No sshd enablement, no host keys baked in. Production stages untouched.
2. **`compose.yaml`** —
   - New service `tailscale-codex` modeled on `cloudflare-tunnel`'s style: pinned
     `image: tailscale/tailscale:<current stable tag>` (exact tag chosen at implementation),
     `restart: unless-stopped`, `depends_on: core`, `environment:` `TS_USERSPACE=true`,
     `TS_AUTH_ONCE=true`, `TS_STATE_DIR=/var/lib/tailscale`, `TS_HOSTNAME=umaxica-global-core`,
     `TS_EXTRA_ARGS=--advertise-tags=tag:umaxica-core`,
     `TS_SERVE_CONFIG=/etc/tailscale/serve/serve.json`,
     `env_file: [{path: ${HOME}/.config/umaxica/tailscale.env, required: false}]` (auth key only;
     file created and later scrubbed by the user, never by Claude), volumes: named
     `tailscale-codex-state` → `/var/lib/tailscale`, bind `./docker/tailscale/serve` →
     `/etc/tailscale/serve:ro`, networks: `remote-access` **only**. No
     `NET_ADMIN`/`NET_RAW`/TUN/privileged/ports/`cap_drop` (cap_drop deferred as post-verification
     hardening).
   - Top-level: network `remote-access: {}`; volumes `tailscale-codex-state: {}` and
     `remote-sshd: {}` (core host-key persistence).
3. **`.devcontainer/compose.override.yml`** — under `core`:
   - `networks: remote-access: {}` (merges with the base 4 networks; aliases untouched),
   - environment `REMOTE_SSHD: "1"`,
   - volumes: `remote-sshd` → `/var/lib/remote-sshd`; bind
     `${HOME}/.config/umaxica/agent-authorized-keys` → `/etc/ssh/authorized_keys.d/global:ro`; bind
     `./docker/core/sshd_config` → `/etc/umaxica/sshd_config:ro`.
   - No new host ports.
4. **`docker/core/sshd_config`** (new) — minimal, explicit: `Port 22`,
   `HostKey /var/lib/remote-sshd/ssh_host_ed25519_key`, `AllowUsers global`, `PermitRootLogin no`,
   `PasswordAuthentication no`, `KbdInteractiveAuthentication no`,
   `AuthenticationMethods publickey`, `AuthorizedKeysFile /etc/ssh/authorized_keys.d/global`,
   `StrictModes yes`, `AllowAgentForwarding no`, `X11Forwarding no`, `PermitTunnel no`,
   `AllowTcpForwarding no`, `AllowStreamLocalForwarding no`, `PermitTTY yes` (kept `yes` until Codex
   App compatibility is verified; tightening to `no` is a documented follow-up),
   `PidFile /run/sshd/sshd.pid`, `UsePAM no`, `LogLevel VERBOSE`. `SetEnv PATH=...` intentionally
   omitted (codex is in `/usr/local/bin`); documented fallback.
5. **`docker/core/entrypoint.sh`** — append a block between the existing chown and `exec "$@"`,
   fully gated on `[ "${REMOTE_SSHD:-0}" = "1" ]`:
   - `sudo install -d -m 0755 -o root -g root /run/sshd`
   - if host key missing: `sudo install -d -m 0700 /var/lib/remote-sshd` +
     `sudo ssh-keygen -q -t ed25519 -N "" -f /var/lib/remote-sshd/ssh_host_ed25519_key`
   - skip if `/run/sshd/sshd.pid` points at a live process (double-start guard)
   - `sudo /usr/sbin/sshd -t -f /etc/umaxica/sshd_config` then
     `sudo /usr/sbin/sshd -f /etc/umaxica/sshd_config`
   - unset `REMOTE_SSHD` when sshd binary is absent? No — fail loudly (`no-silent-fallback`): if
     `REMOTE_SSHD=1` and `sshd`/config/keys are unusable, exit non-zero with a message.
   - Compatible with `set -euo pipefail`; unset var never breaks the default path.
6. **`docker/tailscale/serve/serve.json`** (new) — `{"TCP": {"22": {"TCPForward": "core:22"}}}` —
   explicitly a SPIKE artifact (see §7); fallback variant documented in the ops doc.
7. **`.devcontainer/devcontainer.json`** — expected **no change** (no `runServices`; sidecar starts
   with the project and idles when unauthenticated). Touched only if verification shows otherwise.
8. **`docs/operations/remote-codex-over-tailscale.md`** (new, English, kebab-case per convention) —
   architecture, host-side secret files, tailnet setup checklist (user-owned), enable/disable,
   verification matrix, rollback, PermitTTY tightening follow-up, TCPForward spike status.

No healthcheck added to `core` initially (it has none today; adding one changes recreate semantics).
A `pgrep`-based sshd liveness check is listed in the ops doc as an optional follow-up for the
override file only.

## 6. Security review

- SSH terminates in `core`; sidecar is a dumb TCP relay. Tailscale SSH / `--ssh` not used.
- Pubkey-only, `global`-only, root/password/kbd-interactive/agent-fwd/X11/tunnel/TCP-fwd all denied.
- Zero new host exposure: no `ports:` on sidecar or core (beyond existing 3000/3036), no host sshd/
  tailscaled, no Podman/Docker socket mounts, no systemd units, no firewall changes.
- Secrets stay outside the repo: compose references host paths only
  (`~/.config/umaxica/tailscale.env`, `~/.config/umaxica/agent-authorized-keys`); Claude will not
  create/read/print them. Tailscale state in a named volume; `TS_AUTH_ONCE=true` lets the user
  revoke the auth key after first registration.
- Sidecar runs userspace networking: no TUN, no added capabilities, not privileged. `cap_drop: ALL`
  deferred until after functional verification.
- `authorized_keys` file is mounted read-only from host; with keep-id it appears owned by `global` —
  acceptable to `StrictModes` (owner is the authenticating user); parent dir
  `/etc/ssh/authorized_keys.d` is created root-owned by the bind mount.
- Production stage: no SSH packages, no config, no entrypoint path (env var never set) — verified
  statically in Gate B (`--target production` package check listed in Gate C commands).

## 7. Unknowns requiring spikes

1. **`TS_SERVE_CONFIG` `TCPForward: "core:22"` to a non-localhost peer.** Supported in Tailscale
   source (`ipn/serve.go`) but undocumented in KB. Must be treated as unverified until tested.
   _Fallback:_ `TCPForward: "127.0.0.1:2222"` + a socat relay to `core:22`. The official image has
   no socat, so this would need either a tiny derived image (new file — will be proposed for
   re-approval, not added silently) or a core-side relay. Fallback is documented, not pre-built.
2. **Codex App over SSH with `AllowTcpForwarding no` and PTY behavior.** `PermitTTY yes` initially;
   relaxing `AllowTcpForwarding` to `local` only if the app demonstrably requires it.
3. **Non-interactive PATH.** Expected fine (`/usr/local/bin/codex`); confirmed only in Gate D via
   `ssh … 'command -v codex'` from the Mac (user-run).
4. **`env_file: required: false`** under the user's podman-compose version — verified via
   `podman compose config` in Gate C; fallback is `${TAILSCALE_ENV_FILE:-/dev/null}`-style
   indirection only if needed (would be flagged, not silently applied).
5. **`!reset`/merge behavior** of adding a network + volumes to `core` in the override — verified
   via `podman compose config` before any `up`.

## 8. Exact validation plan

Gate B (static, in-repo): `git diff --check`; `bash -n docker/core/entrypoint.sh`;
`jq . docker/tailscale/serve/serve.json`; YAML parse of both compose files; grep-proof that no
`ports: "22"`, no socket mounts, no secrets entered the diff; confirm `openssh-server` appears only
in the development-stage apt block.

Gate C (user-run on Linux host; this session has no Podman access — commands will be provided):
`podman compose config` (merged view), `podman compose build core`,
`podman build --target production . && podman run --rm <img> sh -c 'command -v sshd; dpkg -s openssh-server'`
(expect absent), then `up -d core tailscale-codex`, `podman compose ps`, logs of both.

Gate D (inside new core): `command -v sshd`, `command -v codex`, `codex --version`,
`sudo /usr/sbin/sshd -t -f /etc/umaxica/sshd_config`, `test -r /etc/ssh/authorized_keys.d/global`,
`test -f /var/lib/remote-sshd/ssh_host_ed25519_key`, `ss -tln` (22 listening, container-only),
`ps aux` (bin/dev alive), `bundle exec rails runner 'puts Rails.env'`, then a narrow smoke test
(e.g. one model test file) before any broader run. Mac-side SSH/Codex-App checks are user-owned.

## 9. Risks and rollback

- Risks: TCPForward spike failure (fallback ready, needs re-approval); podman-compose quirks with
  `env_file.required` / network merge (caught at `compose config` before `up`); sidecar restart-loop
  noise when unauthenticated (cosmetic; same class as cloudflare-tunnel without a token); sshd
  daemonized process dying without container restart (mitigation: optional healthcheck follow-up).
- Rollback: revert the Git changes (Dockerfile, compose.yaml, override, entrypoint) and delete the
  three new files; `podman compose up -d --force-recreate core` restores prior behavior; user
  removes the Tailscale machine and, on explicit approval only, the `tailscale-codex-state` /
  `remote-sshd` volumes. Host secret files are user-managed. Full steps go in the ops doc.

## 10. Approval request

All investigation was read-only; no files were modified. Awaiting: `承認: 実装開始` (Gate B).
